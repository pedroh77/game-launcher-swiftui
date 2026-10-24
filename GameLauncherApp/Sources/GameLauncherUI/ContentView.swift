import SwiftUI
import AppKit
import Dispatch
import LauncherCore
import LauncherRuntime

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var launcher: LaunchController
    @State private var showLog = true

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: Binding(get: { model.selectedAlias }, set: { model.select($0) })) {
                    ForEach(model.visibleGames) { game in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.title).lineLimit(2)
                            Text(L("\(game.alias) · \(game.runnerLabel)"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.padding(.vertical, 3).tag(game.alias)
                    }
                }
                .searchable(text: $model.search, prompt: L("Title, alias or runner"))
                Divider()
                HStack {
                    Text(model.document.games.count == 1 ? L("1 game") : L("\(model.document.games.count) games")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: model.newGame) { Image(systemName: "plus") }
                        .help(L("Add a game")).disabled(!model.loaded || launcher.isRunning)
                }.padding(10)
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 380)
        } detail: {
            VStack(spacing: 0) {
                if let binding = Binding($model.draft) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(binding.wrappedValue.title).font(.title2).bold()
                            Text(binding.wrappedValue.runnerLabel).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isDirty { Text(L("Unsaved changes")).font(.caption).foregroundStyle(.orange) }
                    }.padding()
                    Divider()
                    GameEditor(game: binding).disabled(launcher.isRunning)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller").font(.system(size: 48)).foregroundStyle(.secondary)
                        Text(model.loaded ? L("Select a game or add a new entry") : L("Open a game library to begin"))
                            .font(.title3)
                        if !model.loaded { Button(L("Open Library…"), action: model.openLibrary) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                HStack {
                    Circle().fill(launcher.isRunning ? Color.green : Color.secondary).frame(width: 7, height: 7)
                    Text(launcher.status).font(.caption).lineLimit(1)
                    Spacer()
                    if launcher.hasNativeInput {
                        Button(launcher.needsCursorRestore ? L("Retry Cursor Restore") : L("Show Cursor"), action: launcher.restoreCursor)
                            .help(L("Shows the cursor and cancels any remaining native focus actions; the game keeps running."))
                    }
                    if launcher.needsDisplayRestore {
                        Button(L("Retry Display Restore"), action: launcher.retryDisplayRestoration)
                    }
                    Button(showLog ? L("Hide Log") : L("Show Log")) { showLog.toggle() }
                    Button(L("Save Log…")) { do { try launcher.saveLog() } catch { model.show(error) } }
                }.padding(10)
                if showLog {
                    ScrollView([.horizontal, .vertical]) {
                        Text(launcher.output).font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                    .frame(height: 170)
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .navigationTitle("Game Launcher")
        .toolbar {
            ToolbarItemGroup {
                Button(action: model.duplicateGame) { Label(L("Duplicate"), systemImage: "plus.square.on.square") }
                    .disabled(model.draft == nil || launcher.isRunning)
                Button { model.save() } label: { Label(L("Save"), systemImage: "square.and.arrow.down") }
                    .disabled(!model.canSave)
                Button { model.launch() } label: { Label(L("Launch"), systemImage: "play.fill") }
                    .disabled(model.draft == nil || launcher.isRunning)
                Button(action: model.createLauncher) { Label(L("Create Launcher…"), systemImage: "app.badge") }
                    .disabled(model.draft == nil || launcher.isRunning)
                Button(action: model.stop) { Label(L("Stop Session"), systemImage: "stop.fill") }
                    .disabled(!launcher.isRunning || launcher.isStopping)
            }
        }
        .sheet(item: $model.launcherExport) { request in
            LauncherExportView(request: request)
        }
        .alert("Game Launcher", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button(L("OK"), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

@MainActor
struct PreferencesView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(L("Launching")) {
                HStack {
                    TextField(L("Racket executable"), text: $preferences.racketPath)
                    Button(L("Browse…")) { browse(binding: $preferences.racketPath, directories: false) }
                }
                Text(L("Leave blank to use play's automatic Racket discovery. Racket itself is not bundled."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField(L("Backend folder"), text: $preferences.backendDirectory)
                    Button(L("Browse…")) { browse(binding: $preferences.backendDirectory, directories: true) }
                }
                Text(L("Leave blank to use the backend bundled with this app. An override folder must contain the updated main.rkt and library.rkt."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(L("Hide Game Launcher when launching a game"), isOn: $preferences.hideOnLaunch)
            }
            Section(L("Live Wine environment")) {
                HStack {
                    TextField(L("Script absolute path"), text: $preferences.wineEnvironmentPath)
                    Button(L("Browse…")) { browse(binding: $preferences.wineEnvironmentPath, directories: false) }
                }
                HStack {
                    Button(L("Open in Text Editor"), action: editWineEnvironment)
                    Button(L("Use Default")) { preferences.wineEnvironmentPath = WineEnvironment.defaultPath }
                        .help(L("Resets only the path to ~/bin/libexec/wine_env.sh. Does not change the file contents."))
                }
                Text(L("Trusted shell script, sourced on each Wine launch. Its contents are never bundled. Edits apply next launch without rebuilding; new exports retain this file path. Use the same path in your Terminal alias."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Display manager (opt-in)")) {
                Toggle(L("Use native display switching instead of RDM"), isOn: $preferences.nativeDisplay)
                Text(L("First run the guarded test from the source folder: sh GameLauncherApp/test-native-display.sh 2048x1280. Enable only after it restores your desktop correctly. Supports one built-in, non-mirrored display. Native errors stop launch; no silent RDM fallback."))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Text(L("Game completion and Cancel both restore 1440×900 at 2×. Pointer values and focus clicks are unchanged. Re-create exported apps to change their display manager."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Native focus and cursor (opt-in)")) {
                Toggle(L("Use native clicks and cursor handling"), isOn: $preferences.nativeInput)
                Button(L("Request Accessibility permission…")) { NativeInputPermission.request() }
                Text(L("Replaces cliclick and Cursorcerer for delayed focus in this app and new exports. Uses your existing delay and click sequence. Background cursor hiding uses a private macOS API; keep legacy input available after OS updates."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("Requires Accessibility permission and one built-in, non-mirrored display. Clicks go to the configured screen coordinates, not a verified game window. Out-of-bounds coordinates are refused, never clamped. Input errors stop automation, not the game; there is no silent legacy fallback."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("First test a noncritical game. Each exported app may need its own permission. Re-create exports to change this setting. Your installed Terminal scripts are not updated."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Library")) {
                Text(model.libraryURL.path).font(.caption).textSelection(.enabled)
                HStack {
                    Button(L("Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([model.libraryURL]) }
                    Button(L("Open Another…"), action: model.openLibrary)
                }
                Button(L("Export games.rkt…"), action: model.exportRacketLibrary)
                    .disabled(!model.loaded || model.exportingRacket)
                Text(L("The updated backend reads this JSON library first; games.rkt is a fallback. Export games.rkt for your original scripts without installing or replacing a backend. Notes and extra JSON fields remain in JSON only."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("Save creates games.json.backup and refuses to overwrite a file changed externally. A custom library requires GAME_LAUNCHER_LIBRARY in Terminal; the default path is shared automatically."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Dependencies & scope")) {
                Text(L("Racket, Sikarugir wrappers and Heroic tools stay external. This app edits game settings and launches games; it does not replace Sikarugir Creator, Configuration.app or Heroic, or install/delete games."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("Native display switching is built into the Swift app; RDM is only used by the legacy display path. Racket retains focus timing; native input can replace cliclick and Cursorcerer in this app and new exports. Pointer scaling, black bars, cleanup and save sync retain their existing helpers."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 740, height: 800)
        .disabled(model.launcher.isRunning)
    }
    private func editWineEnvironment() {
        do {
            let url = try WineEnvironment.readableURL(preferences.wineEnvironmentPath)
            // -t chooses the default TEXT editor, not a .sh handler that might
            // execute the script in Terminal. Arguments are never shell-evaluated.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-t", url.path]
            let model = model
            process.terminationHandler = { child in
                if child.terminationStatus != 0 {
                    DispatchQueue.main.async { model.show(LibraryError(L("macOS could not open the Wine environment file in the default text editor."))) }
                }
            }
            try process.run()
        } catch { model.show(error) }
    }
    private func browse(binding: Binding<String>, directories: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directories; panel.canChooseFiles = !directories
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }
}
