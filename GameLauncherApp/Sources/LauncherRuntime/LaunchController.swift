import Foundation
import Combine
import AppKit
import LauncherCore

@MainActor
public final class LaunchController: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var isStopping = false
    @Published public private(set) var status = L("Ready")
    @Published public private(set) var output = L("Launch a game or choose Check Configuration to see backend output here.")
    @Published public private(set) var needsDisplayRestore = false
    @Published public private(set) var needsCursorRestore = false
    @Published public private(set) var hasNativeInput = false
    private var inputLease: InputLease?
    var inputFactory: (URL, String, @escaping (String) -> Void) throws -> InputLease? = { library, alias, report in
        let (document, _) = try LibraryRepository.load(library)
        guard let game = document.games.first(where: { $0.alias == alias }) else {
            throw LibraryError(L("Game alias no longer exists in the live library."))
        }
        guard game.focusDelay != nil else { return nil }
        let coords = game.optionalText("focusCoords")
        return try NativeInputSession(coords: coords.isEmpty ? "1919,1079" : coords, driver: QuartzInputDriver(), report: report)
    }
    private var displayLease: DisplayLease?
    private var rollbackDisplay = false
    // Internal injection point: runtime tests use a fake lease, never CoreGraphics.
    var displayFactory: (URL, String) throws -> DisplayLease = { library, alias in
        let (document, _) = try LibraryRepository.load(library)
        guard let game = document.games.first(where: { $0.alias == alias }) else {
            throw LibraryError(L("Game alias no longer exists in the live library."))
        }
        return try NativeDisplaySession.forGame(game)
    }
    public var onCompletion: ((Int32, Bool) -> Void)?
    private let activateOnFailure: Bool
    private var process: Process?
    private var readHandle: FileHandle?
    private var bytes = Data()
    private var session = UUID()
    private var finishedCode: Int32?
    private var reachedEOF = false
    private let maxLogBytes = 256_000

    public init(activateOnFailure: Bool = true) { self.activateOnFailure = activateOnFailure }

    public static func environment(library: URL, script: URL, racket: String, wineEnvironmentPath: String? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: NativeDisplaySession.environmentKey)
        env.removeValue(forKey: NativeInputSession.environmentKey)
        env[WineEnvironment.environmentKey] = (wineEnvironmentPath?.isEmpty == false ? wineEnvironmentPath : nil) ?? WineEnvironment.defaultPath
        env["GAME_LAUNCHER_SCRIPT"] = script.path
        env["GAME_LAUNCHER_LIBRARY"] = library.path
        env.removeValue(forKey: "GAME_LAUNCHER_RACKET")
        if !racket.isEmpty { env["GAME_LAUNCHER_RACKET"] = (racket as NSString).expandingTildeInPath }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = "\(home)/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        let backend = script.deletingLastPathComponent()
        let blackbars = backend.appendingPathComponent("blackbars")
        if FileManager.default.isExecutableFile(atPath: blackbars.path) {
            env["GAME_LAUNCHER_BLACKBARS"] = blackbars.path
        }
        let loader = backend.appendingPathComponent("runtime_loader")
        if FileManager.default.isExecutableFile(atPath: loader.path) {
            env["GAME_LAUNCHER_ROSETTA_LOADER"] = loader.path
        }
        return env
    }

    public func start(play: URL, script: URL, library: URL, racket: String,
                      alias: String, title: String, infoOnly: Bool, nativeDisplay: Bool = false, nativeInput: Bool = false, wineEnvironmentPath: String? = nil) throws {
        guard !isRunning else { return }
        let winePath = try WineEnvironment.resolvedPath(wineEnvironmentPath)
        if nativeInput && !infoOnly {
            for name in ["focus.rkt", "native-input.rkt"] {
                guard (try String(contentsOf: script.deletingLastPathComponent().appendingPathComponent(name), encoding: .utf8)).contains("native-input-owner-v1") else {
                    throw LibraryError(L("Native input requires the updated bundled backend. Disable native input to use an older backend."))
                }
            }
        }
        if nativeDisplay && !infoOnly {
            // Old external backends would ignore ownership and race the native manager.
            for file in [play, script.deletingLastPathComponent().appendingPathComponent("display.rkt")] {
                guard (try String(contentsOf: file, encoding: .utf8)).contains("native-display-owner-v1") else {
                    throw LibraryError(L("Native display mode requires the updated play and display.rkt. Use the bundled backend or keep RDM selected."))
                }
            }
            displayLease = try displayFactory(library, alias)
        }
        rollbackDisplay = false; needsDisplayRestore = false
        readHandle?.readabilityHandler = nil
        try? readHandle?.close()
        let token = UUID(); session = token
        finishedCode = nil; reachedEOF = false
        let child = Process()
        let pipe = Pipe()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = [play.path] + (infoOnly ? ["--info", alias] : [alias])
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var env = Self.environment(library: library, script: script, racket: racket, wineEnvironmentPath: winePath)
        if let displayLease = displayLease { env[NativeDisplaySession.environmentKey] = displayLease.backendValue }
        child.environment = env
        child.standardOutput = pipe; child.standardError = pipe
        child.standardInput = FileHandle.nullDevice
        bytes = Data("Library: \(library.path)\nBackend: \(script.path)\nSession: \(title) [\(alias)]\n\n".utf8)
        if let displayLease = displayLease { bytes.append(Data((displayLease.summary + "\n\n").utf8)) }
        output = String(decoding: bytes, as: UTF8.self)
        readHandle = pipe.fileHandleForReading
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            // A readiness callback must consume only what is available now.
            // read(upToCount:) can wait for the requested count or EOF on a pipe,
            // withholding short status lines while the game is still running.
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.session == token else { return }
                if data.isEmpty { self.reachedEOF = true; self.finishIfReady() }
                else { self.append(data, session: token) }
            }
        }
        child.terminationHandler = { [weak self] child in
            let code = child.terminationStatus
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.session == token else { return }
                self.restoreInput()
                self.finishedCode = code
                self.finishIfReady()
                // A detached game/store process can inherit stdout. Do not keep
                // the launcher alive forever after play has actually completed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self, self.session == token, self.isRunning else { return }
                    self.finishIfReady(force: true)
                }
            }
        }
        do {
            if nativeInput && !infoOnly {
                inputLease = try inputFactory(library, alias) { [weak self] message in
                    if self?.inputLease?.needsRestoration == true {
                        self?.needsCursorRestore = true
                        self?.status = L("Cursor restore failed — use Retry Cursor Restore")
                    }
                    self?.append(Data((message + "\n").utf8), session: token)
                }
                hasNativeInput = inputLease != nil
                env[NativeInputSession.environmentKey] = inputLease?.backendValue
                child.environment = env
            }
            try displayLease?.begin()
            try child.run()
            try? pipe.fileHandleForWriting.close()
            process = child; isRunning = true; isStopping = false
            status = infoOnly ? L("Checking configuration…") : L("Running: \(title)")
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            readHandle = nil
            status = L("Could not start backend")
            rollbackDisplay = true
            let inputRestored = restoreInput()
            let displayRestored = restoreDisplay()
            if !inputRestored || !displayRestored {
                // Keep the owner and lock alive, and expose Retry instead of silently
                // abandoning a mode after a launch/start rollback failure.
                isRunning = true; finishedCode = 70; reachedEOF = true
            }
            throw error
        }
    }
    private func finishIfReady(force: Bool = false) {
        guard isRunning, !needsDisplayRestore, let code = finishedCode, reachedEOF || force else { return }
        readHandle?.readabilityHandler = nil
        try? readHandle?.close(); readHandle = nil
        process = nil
        let inputRestored = restoreInput()
        let displayRestored = restoreDisplay()
        guard inputRestored && displayRestored else { return }
        let stopped = isStopping
        isRunning = false; isStopping = false; process = nil
        status = stopped ? L("Stopped (exit \(code))") : (code == 0 ? L("Finished") : L("Failed (exit \(code))"))
        if activateOnFailure && code != 0 && !stopped { NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true) }
        onCompletion?(code, stopped)
    }
    @discardableResult
    private func restoreInput() -> Bool {
        guard let lease = inputLease else { return true }
        do {
            try lease.close()
            inputLease = nil; hasNativeInput = false; needsCursorRestore = false
            return true
        } catch {
            needsCursorRestore = true
            status = L("Cursor restore failed — use Retry Cursor Restore")
            append(Data(("CURSOR RESTORE ERROR: " + error.localizedDescription + "\n").utf8), session: session)
            if activateOnFailure { NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true) }
            return false
        }
    }
    public func restoreCursor() {
        if restoreInput() { finishIfReady(force: true) }
    }
    private func restoreDisplay() -> Bool {
        guard let lease = displayLease else { return true }
        do {
            if rollbackDisplay { try lease.abort() } else { try lease.restore() }
            displayLease = nil; needsDisplayRestore = false
            append(Data("Native display restoration completed.\n".utf8), session: session)
            return true
        } catch {
            needsDisplayRestore = true
            status = L("Display restore failed — restore the display topology and click Retry Display Restore")
            if activateOnFailure { NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true) }
            append(Data(("DISPLAY RESTORE ERROR: " + error.localizedDescription + "\n").utf8), session: session)
            return false
        }
    }
    public func retryDisplayRestoration() {
        guard needsDisplayRestore else { return }
        if restoreDisplay() { finishIfReady(force: true) }
    }
    private func append(_ data: Data, session token: UUID) {
        guard session == token else { return }
        bytes.append(data)
        if bytes.count > maxLogBytes { bytes.removeFirst(bytes.count - maxLogBytes) }
        output = String(decoding: bytes, as: UTF8.self)
    }
    public func stop() {
        guard let process = process, process.isRunning, !isStopping else { return }
        isStopping = true; status = L("Stopping and restoring settings…")
        restoreInput() // Stop pending focus actions immediately, before backend cleanup.
        process.terminate() // SIGTERM directly to play, not to an extra wrapper shell.
    }
    public func saveLog() throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "game-launcher.log"
        if panel.runModal() == .OK, let url = panel.url {
            try output.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
