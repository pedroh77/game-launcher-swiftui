import AppKit
import Dispatch
import SwiftUI
import LauncherCore
import LauncherRuntime

@main
@MainActor
enum GameRunnerMain {
    static func main() {
        // A safe command-line check for exported bundles: no windows or game launch.
        if Array(CommandLine.arguments.dropFirst()) == ["--check"] {
            do {
                guard let resources = Bundle.main.resourceURL else { throw LibraryError(L("Missing app resources.")) }
                let config = try StandaloneConfiguration.load(resources: resources)
                let backend = resources.appendingPathComponent("Backend")
                let child = Process()
                child.executableURL = URL(fileURLWithPath: "/bin/sh")
                child.arguments = [backend.appendingPathComponent("play").path, "--info", config.alias]
                child.environment = LaunchController.environment(library: URL(fileURLWithPath: config.libraryPath),
                                                                 script: backend.appendingPathComponent("main.rkt"),
                                                                 racket: config.racketPath, wineEnvironmentPath: config.wineEnvironmentPath)
                try child.run(); child.waitUntilExit()
                exit(child.terminationStatus)
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }
        guard CommandLine.arguments.dropFirst().allSatisfy({ $0.hasPrefix("-psn_") }) else {
            FileHandle.standardError.write(Data("Usage: GameRunner [--check]\n".utf8)); exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = RunnerDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class OutputPanel: NSPanel {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class RunnerDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let launcher = LaunchController(activateOnFailure: false)
    private var panel: OutputPanel?
    private var screenNumber: NSNumber?
    private var startupError: String?
    private var config: StandaloneConfiguration?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Native mode switching occurs synchronously inside start(). Observe it
        // before launching, not afterwards (when the notification may be lost).
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        defer { scheduleAnchorWindow() }
        do {
            guard let resources = Bundle.main.resourceURL else { throw LibraryError(L("Missing app resources.")) }
            let configuration = try StandaloneConfiguration.load(resources: resources)
            config = configuration
            let library = URL(fileURLWithPath: configuration.libraryPath)
            let (document, _) = try LibraryRepository.load(library)
            guard let game = document.games.first(where: { $0.alias == configuration.alias }) else {
                throw LibraryError(L("Game alias '\(configuration.alias)' no longer exists. Re-create this launcher after renaming an alias."))
            }
            guard !game.exeName.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw LibraryError(L("Set the game's process/executable name in Game Launcher first."))
            }
            if !game.platform.hasPrefix("steam-") && game.storeID.trimmingCharacters(in: .whitespaces).isEmpty {
                throw LibraryError(L("Set the game's store ID or executable path in Game Launcher first."))
            }
            if game.usesWine { _ = try WineEnvironment.readableURL(configuration.wineEnvironmentPath) }
            if configuration.presentation.showsWindow {
                showWindow(title: configuration.title, textMode: configuration.presentation == .text)
            }
            launcher.onCompletion = { [weak self] _, _ in
                guard let self = self else { return }
                self.writeSessionLog()
                NSApp.terminate(nil)
            }
            let backend = resources.appendingPathComponent("Backend")
            try launcher.start(play: backend.appendingPathComponent("play"), script: backend.appendingPathComponent("main.rkt"),
                               library: library, racket: configuration.racketPath, alias: configuration.alias,
                               title: configuration.title, infoOnly: false, nativeDisplay: configuration.nativeDisplay == true, nativeInput: configuration.nativeInput == true, wineEnvironmentPath: configuration.wineEnvironmentPath)
        } catch {
            startupError = error.localizedDescription
            if config?.presentation.showsWindow != false {
                showWindow(title: config?.title ?? "Game Launcher", textMode: true)
            }
            writeSessionLog()
            if config?.presentation.showsWindow == false {
                exit(1)
            }
        }
    }
    private func showWindow(title: String, textMode: Bool) {
        if panel == nil {
            let window = OutputPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 160),
                                     styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isFloatingPanel = false
            window.level = .normal
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = true
            window.animationBehavior = .none
            window.delegate = self
            panel = window
            screenNumber = (NSScreen.main ?? NSScreen.screens.first)?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        }
        guard let panel = panel else { return }
        panel.title = title
        panel.contentView = NSHostingView(rootView: RunnerView(launcher: launcher, textMode: textMode,
            error: startupError, resize: { [weak self] expanded in self?.resize(expanded: expanded) },
            close: { [weak self] in self?.cancelOrClose() }))
        resize(expanded: textMode)
        panel.orderFront(nil) // Not makeKeyAndOrderFront; never activate the app.
    }
    private func resize(expanded: Bool) {
        panel?.setContentSize(NSSize(width: 560, height: expanded ? 330 : 160))
        anchorWindow()
    }
    private var anchorGeneration = 0
    @objc private func screenChanged() { scheduleAnchorWindow() }
    private func scheduleAnchorWindow() {
        anchorGeneration += 1
        let generation = anchorGeneration
        anchorWindow()
        // AppKit may update NSScreen and constrain the panel after CoreGraphics
        // returns. Re-read the geometry on the next turn and during that short
        // settling interval. Bounded, non-activating, and no focus/click changes.
        for delay in [0.0, 0.1, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.anchorGeneration == generation else { return }
                self.anchorWindow()
            }
        }
    }
    private func anchorWindow() {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return }
        screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        guard let panel = panel else { return }
        panel.setFrameTopLeftPoint(LauncherWindowPlacement.topLeft(
            screenFrame: screen.frame, visibleFrame: screen.visibleFrame, windowWidth: panel.frame.width))
    }
    private func cancelOrClose() {
        if launcher.needsCursorRestore { launcher.restoreCursor() }
        else if launcher.needsDisplayRestore { launcher.retryDisplayRestoration() }
        else if launcher.isRunning { launcher.stop() }
        else { NSApp.terminate(nil) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancelOrClose()
        return !launcher.isRunning
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if launcher.needsDisplayRestore || launcher.needsCursorRestore { return .terminateCancel }
        if launcher.isRunning { launcher.stop(); return .terminateCancel }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !launcher.isRunning }
    private func writeSessionLog() {
        let fm = FileManager.default
        let folder = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Game Launcher")
        let identifier = Bundle.main.bundleIdentifier ?? "standalone"
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let text = "\(Date())\n\(launcher.status)\n\(startupError ?? "")\n\n\(launcher.output)\n"
            try text.write(to: folder.appendingPathComponent(identifier + ".log"), atomically: true, encoding: .utf8)
        } catch { NSLog("Could not save game launcher log: %@", error.localizedDescription) }
    }
}

@MainActor
private struct RunnerView: View {
    @ObservedObject var launcher: LaunchController
    @State private var expanded: Bool
    let error: String?
    let resize: (Bool) -> Void
    let close: () -> Void

    init(launcher: LaunchController, textMode: Bool, error: String?,
         resize: @escaping (Bool) -> Void, close: @escaping () -> Void) {
        self.launcher = launcher; _expanded = State(initialValue: textMode)
        self.error = error; self.resize = resize; self.close = close
    }
    private var currentMessage: String {
        launcher.output.split(whereSeparator: { $0.isNewline }).last.map(String.init) ?? launcher.status
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(error ?? (launcher.isStopping ? launcher.status : currentMessage))
                .font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                .help(error ?? currentMessage)
            if launcher.isRunning { ProgressView().progressViewStyle(.linear) }
            if expanded {
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(error.map { $0 + "\n\n" + launcher.output } ?? launcher.output).font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled).padding(8)
                            Color.clear.frame(height: 1).id("end")
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: launcher.output) { _ in proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button(expanded ? L("Hide Details") : L("Show Details")) { expanded.toggle(); resize(expanded) }
                if expanded { Button(L("Save Log…")) { try? launcher.saveLog() } }
                Spacer()
                if launcher.hasNativeInput {
                    Button(launcher.needsCursorRestore ? L("Retry Cursor Restore") : L("Show Cursor"), action: launcher.restoreCursor)
                        .help(L("Shows the cursor and cancels any remaining native focus actions; the game keeps running."))
                }
                Button(launcher.needsDisplayRestore ? L("Retry Display Restore") : (launcher.isStopping ? L("Cancelling…") : (launcher.isRunning ? L("Cancel") : L("Close"))), action: close)
                    .disabled(launcher.isStopping && !launcher.needsDisplayRestore)
                    .help(L("Cancel runs the existing cleanup and may close other Wine sessions. Closing the window does the same."))
            }
            Text(error == nil ? L("Cancel uses your existing cleanup, including other Wine sessions.") : L("Fix the configuration in Game Launcher, then reopen this app."))
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
