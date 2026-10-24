import SwiftUI
import AppKit
import LauncherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.mayQuit() == false ? .terminateCancel : .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil) }
        return true
    }
}

@main
@MainActor
struct GameLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window(L("Game Launcher"), id: "library") {
            ContentView(model: model, launcher: model.launcher)
                .environment(\.locale, L10n.locale)
                .onAppear {
                    delegate.model = model
                    model.start()
                }
        }
        .defaultSize(width: 1120, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("New Game"), action: model.newGame).keyboardShortcut("n")
                    .disabled(!model.loaded || model.launcher.isRunning)
                Button(L("Open Library…"), action: model.openLibrary).keyboardShortcut("o")
                    .disabled(model.launcher.isRunning)
                Button(L("Export Library Copy…"), action: model.exportLibrary)
                    .disabled(!model.loaded)
                Button(L("Export games.rkt…"), action: model.exportRacketLibrary)
                    .disabled(!model.loaded || model.exportingRacket)
            }
            CommandGroup(replacing: .saveItem) {
                Button(L("Save Game")) { model.save() }.keyboardShortcut("s").disabled(!model.canSave)
                Button(L("Discard Game Edits"), action: model.discardEdits)
                    .disabled(!model.isDirty || model.launcher.isRunning)
                Button(L("Reload Library"), action: model.reload).keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.launcher.isRunning)
            }
            CommandMenu(L("Game")) {
                Button(L("Launch")) { model.launch() }.keyboardShortcut("l")
                    .disabled(model.draft == nil || model.launcher.isRunning)
                Button(L("Create Launcher…"), action: model.createLauncher)
                    .disabled(model.draft == nil || model.launcher.isRunning)
                Button(L("Check Configuration")) { model.launch(infoOnly: true) }
                    .disabled(model.draft == nil || model.launcher.isRunning)
                Button(L("Stop Session…"), action: model.stop)
                    .disabled(!model.launcher.isRunning || model.launcher.isStopping)
                Divider()
                Button(L("Duplicate"), action: model.duplicateGame).keyboardShortcut("d")
                    .disabled(model.draft == nil || model.launcher.isRunning)
                Button(L("Remove Entry…"), action: model.deleteGame)
                    .disabled(model.selectedAlias == nil || model.launcher.isRunning)
            }
        }
        Settings { PreferencesView(preferences: model.preferences, model: model) }
    }
}
