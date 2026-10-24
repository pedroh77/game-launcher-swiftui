import Foundation
import CoreGraphics
import Darwin
import LauncherCore

// An explicit lease keeps the display owner alive until play's cleanup finishes.
// Tests inject a driver; no XCTest needs to touch a real display.
protocol DisplayLease: AnyObject {
    var backendValue: String { get }
    var summary: String { get }
    func begin() throws
    func restore() throws
    func abort() throws
}

struct DisplayModeDescription: Equatable {
    let id: UInt32
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    func matches(_ spec: DisplayModeSpec) -> Bool {
        spec.width > 0 && spec.height > 0 && [1, 2].contains(spec.scale) &&
        spec.width <= Int.max / spec.scale && spec.height <= Int.max / spec.scale &&
        width == spec.width && height == spec.height &&
        pixelWidth == spec.width * spec.scale && pixelHeight == spec.height * spec.scale
    }
    func equivalent(to other: Self) -> Bool {
        width == other.width && height == other.height && pixelWidth == other.pixelWidth &&
        pixelHeight == other.pixelHeight && abs(refreshRate - other.refreshRate) < 0.5
    }
    var label: String { "\(width)×\(height), framebuffer \(pixelWidth)×\(pixelHeight), \(refreshRate) Hz" }
    static func select(_ spec: DisplayModeSpec, modes: [Self], current: Self) throws -> Self {
        let matches = modes.filter { $0.matches(spec) }.sorted {
            if ($0.id == current.id) != ($1.id == current.id) { return $0.id == current.id }
            let a = abs($0.refreshRate - current.refreshRate), b = abs($1.refreshRate - current.refreshRate)
            return a == b ? $0.id < $1.id : a < b
        }
        guard let mode = matches.first else { throw LibraryError(L("Native display mode unavailable: \(spec.label). Nothing was changed. Use RDM or choose a listed profile.")) }
        return mode
    }
}

protocol DisplayDriver {
    func current() throws -> DisplayModeDescription
    func modes() throws -> [DisplayModeDescription]
    func set(_ mode: DisplayModeDescription) throws
}

private final class DisplayLock {
    private var descriptor: Int32 = -1
    init() throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Game Launcher")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("native-display.lock").path
        let fd = open(path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        guard fd >= 0 else { throw LibraryError(L("Cannot open the native display lock.")) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw LibraryError(L("Another native game session or display test owns the display. Finish it first."))
        }
        descriptor = fd
    }
    deinit { if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor) } }
}

private final class CoreGraphicsDisplayDriver: DisplayDriver {
    let display: CGDirectDisplayID
    init() throws {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count == 1 else {
            throw LibraryError(L("Native switching currently requires exactly one online display. Disconnect other displays or use RDM."))
        }
        display = CGMainDisplayID()
        guard CGDisplayIsBuiltin(display) != 0 else {
            throw LibraryError(L("This first native display release supports the built-in display only. Use RDM for an external monitor."))
        }
        try validate()
    }
    private func validate() throws {
        guard CGDisplayIsOnline(display) != 0, CGDisplayIsBuiltin(display) != 0,
              CGDisplayMirrorsDisplay(display) == kCGNullDirectDisplay, CGDisplayIsInMirrorSet(display) == 0 else {
            throw LibraryError(L("The original display is disconnected or mirrored. Restore its topology and retry display restoration."))
        }
    }
    private func describe(_ mode: CGDisplayMode) -> DisplayModeDescription {
        .init(id: UInt32(truncatingIfNeeded: mode.ioDisplayModeID), width: mode.width, height: mode.height,
              pixelWidth: mode.pixelWidth, pixelHeight: mode.pixelHeight, refreshRate: mode.refreshRate)
    }
    private func available() throws -> [CGDisplayMode] {
        try validate()
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] else {
            throw LibraryError(L("Could not enumerate native display modes."))
        }
        return modes
    }
    func current() throws -> DisplayModeDescription {
        try validate()
        guard let mode = CGDisplayCopyDisplayMode(display) else { throw LibraryError(L("Could not read the current display mode.")) }
        return describe(mode)
    }
    func modes() throws -> [DisplayModeDescription] { try available().map(describe) }
    func set(_ mode: DisplayModeDescription) throws {
        // Re-enumerate instead of using a stale CGDisplayMode after topology changes.
        guard let target = try available().first(where: { describe($0) == mode }) else {
            throw LibraryError(L("The requested display mode disappeared. No substitute was selected."))
        }
        let result = CGDisplaySetDisplayMode(display, target, nil)
        guard result == .success else { throw LibraryError(L("Native display switch failed: CoreGraphics error \(result.rawValue).")) }
        guard try current().equivalent(to: mode) else { throw LibraryError(L("macOS did not confirm the requested display mode.")) }
    }
}

final class NativeDisplaySession: DisplayLease {
    static let environmentKey = "GAME_LAUNCHER_NATIVE_DISPLAY"
    let backendValue: String
    let summary: String
    private let driver: DisplayDriver?
    private let target: DisplayModeDescription?
    private let original: DisplayModeDescription?
    private let finalMode: DisplayModeDescription?
    private var restoreMode: DisplayModeDescription?
    private var lock: AnyObject?
    private var begun = false

    static func forGame(_ game: GameRecord) throws -> NativeDisplaySession {
        let spec = try DisplayModeSpec.forGame(game)
        if spec == nil { return try NativeDisplaySession(spec: nil, driver: nil) }
        let lock = try DisplayLock()
        return try NativeDisplaySession(spec: spec, driver: CoreGraphicsDisplayDriver(), lock: lock)
    }
    static func forTest(_ spec: DisplayModeSpec) throws -> NativeDisplaySession {
        let lock = try DisplayLock()
        return try NativeDisplaySession(spec: spec, driver: CoreGraphicsDisplayDriver(), restorePrevious: true, lock: lock)
    }
    // Tests pass no lock and a fake driver. Construction is preflight only.
    init(spec: DisplayModeSpec?, driver: DisplayDriver?, restorePrevious: Bool = false, lock: AnyObject? = nil) throws {
        self.driver = driver; self.lock = lock
        guard let spec = spec, let driver = driver else {
            target = nil; original = nil; finalMode = nil
            backendValue = "skip"; summary = "Native display: keep current display (no resolution or pointer changes)."
            return
        }
        let current = try driver.current()
        original = current
        // Match the legacy 1080p skip, without Finder automation or an error-as-skip fallback.
        if !restorePrevious && current.width == 1920 && current.height == 1080 {
            target = nil; finalMode = nil; backendValue = "skip"
            summary = "Native display: preserving the existing 1920×1080 skip."
            return
        }
        let modes = try driver.modes()
        guard modes.contains(current) else {
            throw LibraryError(L("The captured desktop mode is not in the public mode list. Cannot guarantee a rollback target; nothing was changed."))
        }
        let selected = try DisplayModeDescription.select(spec, modes: modes, current: current)
        let restore: DisplayModeDescription
        if restorePrevious { restore = current }
        else { restore = try DisplayModeDescription.select(.restore, modes: modes, current: current) }
        target = selected; finalMode = restore; backendValue = spec.backendValue
        summary = "Native display: \(selected.label)\nRestore: \(restore.label)\nCaptured desktop: \(current.label)"
    }
    func begin() throws {
        guard !begun else { throw LibraryError(L("Display session already started.")) }
        begun = true
        guard let driver = driver, let target = target, let original = original else { return }
        guard try driver.current() == original else { throw LibraryError(L("The display changed after preflight. Retry without another display manager running.")) }
        // Even a failed set can have changed hardware. On failure retain the original
        // desktop as the rollback target, and let the caller retry if rollback fails.
        restoreMode = original
        try driver.set(target)
        restoreMode = finalMode
    }
    func abort() throws {
        if restoreMode != nil { restoreMode = original }
        try restore()
    }
    func restore() throws {
        if let driver = driver, let mode = restoreMode {
            try driver.set(mode)
            restoreMode = nil
        }
        lock = nil // Release only after a successful restore (or a no-op session).
    }
}

// Public entry point used only by the guarded diagnostic executable.
// It uses exactly the same selection, locking, verification and restoration code.
public final class NativeDisplayTestSession {
    private let lease: NativeDisplaySession
    public var summary: String { lease.summary }
    public init(profile: String) throws {
        guard let spec = DisplayModeSpec.presets[profile] ?? (profile == "1440x900" ? .restore : nil) else {
            throw LibraryError(L("Choose 2560x1600, 2048x1280, 1680x1050, 1920x1200, 1280x800 or 1440x900."))
        }
        lease = try NativeDisplaySession.forTest(spec)
    }
    public func begin() throws { try lease.begin() }
    public func restore() throws { try lease.restore() }
}
