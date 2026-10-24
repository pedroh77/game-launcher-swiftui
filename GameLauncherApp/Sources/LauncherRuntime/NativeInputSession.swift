import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import Darwin
import LauncherCore
import CursorBridge

@MainActor
protocol InputLease: AnyObject {
    var backendValue: String { get }
    var needsRestoration: Bool { get }
    func cancel() throws
    func close() throws
}

@MainActor
protocol NativeInputDriver: AnyObject {
    func preflight() throws
    func click(_ point: CGPoint) throws
    func hide() throws
    func restore() throws
}

@MainActor
final class QuartzInputDriver: NativeInputDriver {
    private var hideCount = 0
    private var propertyAttempted = false
    func preflight() throws {
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            throw LibraryError(L("Native input needs Accessibility permission for this app. Grant it in System Settings, then reopen the app. Exported apps may need their own permission."))
        }
        guard probe_cursor_symbols() != 0 else {
            throw LibraryError(L("Native cursor API is unavailable on this macOS version. Disable native input to use cliclick and Cursorcerer."))
        }
        try checkDisplay()
    }
    private func checkDisplay() throws {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count == 1,
              CGDisplayIsBuiltin(CGMainDisplayID()) != 0,
              CGDisplayIsInMirrorSet(CGMainDisplayID()) == 0 else {
            throw LibraryError(L("Native input currently requires one built-in, non-mirrored display."))
        }
    }
    func click(_ point: CGPoint) throws {
        try checkDisplay()
        guard CGPreflightPostEventAccess() else { throw LibraryError(L("Native input permission was revoked. No click posted.")) }
        guard CGDisplayBounds(CGMainDisplayID()).contains(point) else {
            throw LibraryError(L("Focus coordinates are outside the current display. Correct this game's coordinates or use legacy input; no click was posted."))
        }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            throw LibraryError(L("Could not create native mouse events."))
        }
        // Both events exist before posting. Keep the short pair synchronous so
        // Stop cannot discard a queued mouse-up. These are separate single clicks.
        down.flags = []; up.flags = []
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
        up.post(tap: .cghidEventTap)
    }
    func hide() throws {
        try preflight()
        if !propertyAttempted {
            propertyAttempted = true
            guard probe_set_background_cursor(1) == 0 else { throw LibraryError(L("Native background cursor property failed.")) }
        }
        guard CGDisplayHideCursor(CGMainDisplayID()) == .success else { throw LibraryError(L("Native cursor hide failed.")) }
        hideCount += 1
    }
    func restore() throws {
        var restoreError: Error?
        while hideCount > 0 {
            if CGDisplayShowCursor(CGMainDisplayID()) != .success {
                if restoreError == nil {
                    restoreError = LibraryError(L("Native cursor restoration failed. Use Retry Cursor Restore."))
                }
            }
            hideCount -= 1
        }
        if propertyAttempted {
            guard probe_set_background_cursor(0) == 0 else { throw LibraryError(L("Native cursor property reset failed. Use Retry Cursor Restore.")) }
            propertyAttempted = false
        }
        if let error = restoreError {
            throw error
        }
    }
}

// A private, acknowledged control channel, completely separate from game logs.
// Only four actions from the live game's existing focus sequence are accepted.
@MainActor
final class NativeInputSession: InputLease {
    static let environmentKey = "GAME_LAUNCHER_NATIVE_INPUT"
    struct Request: Codable {
        var token: String
        var sequence: Int
        var action: String
        var coords: String?
        var createdAt: Double
    }
    struct Response: Codable {
        var sequence: Int
        var ok: Bool
        var error: String?
    }
    let directory: URL
    let token: String
    let backendValue: String
    private let coords: String
    private let point: CGPoint
    private let driver: NativeInputDriver
    private let report: (String) -> Void
    private var timer: Timer?
    private var lockFD: Int32 = -1
    private var lastSequence = 0
    private var active = true
    private var closed = false
    private(set) var needsRestoration = false

    init(coords: String, driver: NativeInputDriver, report: @escaping (String) -> Void,
         acquireLock: Bool = true, startTimer: Bool = true) throws {
        let parts = coords.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else {
            throw LibraryError(L("Focus coordinates must be integers in x,y format."))
        }
        self.coords = coords; self.point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        self.driver = driver; self.report = report
        try driver.preflight()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("game-input-" + UUID().uuidString)
        let identity = UUID().uuidString
        directory = folder; token = identity
        let data = try JSONSerialization.data(withJSONObject: ["directory": folder.path, "token": identity])
        backendValue = String(decoding: data, as: UTF8.self)
        if acquireLock {
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("org.personal.game-launcher-input.lock").path
            lockFD = Darwin.open(path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
                throw LibraryError(L("Another native input session is active, or its lock is unavailable."))
            }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        } catch {
            if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
            throw error
        }
        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.poll() }
            }
        }
    }
    func poll(now: Date = Date()) {
        guard active else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: directory.appendingPathComponent("cancelled").path) {
                try cancel(); return
            }
            let url = directory.appendingPathComponent("request.json")
            guard fm.fileExists(atPath: url.path) else { return }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 4096 else { throw LibraryError(L("Native input request is too large.")) }
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: url))
            guard request.token == token else { throw LibraryError(L("Native input owner token mismatch.")) }
            if request.sequence == lastSequence { return } // Already acknowledged; never repeat a click.
            let actions = ["click", "click", "hide", "click", "hide"]
            guard request.sequence == lastSequence + 1, (1...5).contains(request.sequence),
                  request.action == actions[request.sequence - 1],
                  (request.action == "hide" ? request.coords == nil : request.coords == coords) else {
                throw LibraryError(L("Native input sequence or coordinates do not match this game."))
            }
            let age = now.timeIntervalSince1970 - request.createdAt
            guard age.isFinite, age >= -0.5, age <= 2 else { throw LibraryError(L("Stale native input request refused; no delayed click posted.")) }
            if request.action == "click" { try driver.click(point) } else { try driver.hide() }
            lastSequence = request.sequence
            try JSONEncoder().encode(Response(sequence: request.sequence, ok: true, error: nil))
                .write(to: directory.appendingPathComponent("response.json"), options: .atomic)
            report("Native input: \(request.action) \(request.sequence)/5")
        } catch {
            report("NATIVE INPUT ERROR: " + error.localizedDescription)
            do { try cancel() }
            catch { report("CURSOR RESTORE ERROR: " + error.localizedDescription) }
        }
    }
    func cancel() throws {
        guard !closed else { return }
        active = false; timer?.invalidate(); timer = nil
        // Cancel the producer before restoring; it must never fall back to tools.
        try? Data().write(to: directory.appendingPathComponent("cancelled"), options: .atomic)
        do { try driver.restore(); needsRestoration = false }
        catch { needsRestoration = true; throw error }
    }
    func close() throws {
        guard !closed else { return }
        try cancel() // Failure retains the owner/lock so the UI can offer Retry.
        try? FileManager.default.removeItem(at: directory)
        if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
        closed = true
    }
}

public enum NativeInputPermission {
    public static var isGranted: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }
    @discardableResult public static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
