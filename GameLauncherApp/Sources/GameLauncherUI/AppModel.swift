import SwiftUI
import AppKit
import Combine
import LauncherCore
import LauncherRuntime

@MainActor
final class Preferences: ObservableObject {
    @Published var wineEnvironmentPath: String { didSet { UserDefaults.standard.set(wineEnvironmentPath, forKey: "wineEnvironmentPath") } }
    @Published var racketPath: String { didSet { UserDefaults.standard.set(racketPath, forKey: "racketPath") } }
    @Published var backendDirectory: String { didSet { UserDefaults.standard.set(backendDirectory, forKey: "backendDirectory") } }
    @Published var nativeInput: Bool { didSet { UserDefaults.standard.set(nativeInput, forKey: "nativeInput") } }
    @Published var nativeDisplay: Bool { didSet { UserDefaults.standard.set(nativeDisplay, forKey: "nativeDisplay") } }
    @Published var hideOnLaunch: Bool { didSet { UserDefaults.standard.set(hideOnLaunch, forKey: "hideOnLaunch") } }
    init() {
        wineEnvironmentPath = UserDefaults.standard.string(forKey: "wineEnvironmentPath") ?? WineEnvironment.defaultPath
        nativeInput = (UserDefaults.standard.object(forKey: "nativeInput") as? Bool) ?? true
        nativeDisplay = UserDefaults.standard.bool(forKey: "nativeDisplay")
        racketPath = UserDefaults.standard.string(forKey: "racketPath") ?? ""
        backendDirectory = UserDefaults.standard.string(forKey: "backendDirectory") ?? ""
        hideOnLaunch = (UserDefaults.standard.object(forKey: "hideOnLaunch") as? Bool) ?? true
    }
}

enum Resources {
    static func url(_ name: String) throws -> URL {
        let development = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let roots = [Bundle.main.resourceURL, development].compactMap { $0 }
        for root in roots {
            let path = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: path.path) { return path }
        }
        throw LibraryError(L("Missing bundled resource: \(name). Run the build-macos.sh script to prepare the application."))
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var document = LibraryDocument(games: [])
    @Published var draft: GameRecord?
    @Published private(set) var selectedAlias: String?
    @Published private(set) var libraryURL = LibraryRepository.defaultURL
    @Published private(set) var loaded = false
    @Published var search = ""
    @Published var errorMessage: String?
    @Published private(set) var exportingRacket = false
    @Published var launcherExport: LauncherExportRequest?
    let preferences = Preferences()
    let launcher = LaunchController()
    private var diskData = Data()
    private var original: GameRecord?
    private var launchObservation: AnyCancellable?

    init() {
        launchObservation = launcher.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var isDirty: Bool { draft != original }
    var visibleGames: [GameRecord] {
        document.games.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) ||
            $0.alias.localizedCaseInsensitiveContains(search) || $0.runnerLabel.localizedCaseInsensitiveContains(search)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var canSave: Bool { loaded && draft != nil && isDirty && !launcher.isRunning }

    func start() {
        guard !loaded else { return }
        do {
            if let saved = UserDefaults.standard.string(forKey: "libraryPath") {
                libraryURL = URL(fileURLWithPath: saved)
            }
            if !FileManager.default.fileExists(atPath: libraryURL.path) {
                // Only create the default library. A missing custom path is an error,
                // never an excuse to silently replace a user's configuration.
                guard libraryURL == LibraryRepository.defaultURL else { throw LibraryError(L("The selected library is missing. Use File → Open Library to locate it.")) }
                let seed = try Data(contentsOf: Resources.url("games.seed.json"))
                _ = try JSONDecoder().decode(LibraryDocument.self, from: seed)
                try FileManager.default.createDirectory(at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try seed.write(to: libraryURL, options: .withoutOverwriting)
            }
            try load(libraryURL)
        } catch { show(error) }
    }
    private func load(_ url: URL) throws {
        let (doc, bytes) = try LibraryRepository.load(url)
        document = doc; diskData = bytes; libraryURL = url; loaded = true
        let game = doc.games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }.first
        selectedAlias = game?.alias; draft = game; original = game
        search = ""
        UserDefaults.standard.set(url.path, forKey: "libraryPath")
    }
    func show(_ error: Error) { errorMessage = error.localizedDescription }

    @discardableResult
    func resolveEdits() -> Bool {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = L("Save changes to this game?")
        alert.informativeText = L("You have unsaved changes to \(draft?.title ?? L("this game")).")
        alert.addButton(withTitle: L("Save"))
        alert.addButton(withTitle: L("Discard"))
        alert.addButton(withTitle: L("Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertSecondButtonReturn: draft = original; return true
        default: return false
        }
    }
    func select(_ alias: String?) {
        guard alias != selectedAlias, resolveEdits() else { return }
        selectedAlias = alias
        draft = document.games.first { $0.alias == alias }
        original = draft
    }
    func uniqueAlias(_ base: String) -> String {
        let existing = Set(document.games.map(\.alias))
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }
    func newGame() {
        guard loaded, !launcher.isRunning, resolveEdits() else { return }
        selectedAlias = nil; original = nil
        draft = GameRecord.new(alias: uniqueAlias("new-game"))
        search = ""
    }
    func duplicateGame() {
        guard !launcher.isRunning, resolveEdits(), var copy = draft else { return }
        copy.alias = uniqueAlias(copy.alias + "-copy")
        copy.title += L(" (Copy)")
        selectedAlias = nil; original = nil; draft = copy; search = ""
    }
    private func documentIncludingDraft() throws -> LibraryDocument {
        var result = document
        if let game = draft {
            try game.validate()
            if let oldAlias = selectedAlias, let i = result.games.firstIndex(where: { $0.alias == oldAlias }) {
                result.games[i] = game
            } else { result.games.append(game) }
        }
        try result.validate()
        return result
    }
    @discardableResult
    func save() -> Bool {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard loaded, !launcher.isRunning, let game = draft else { return false }
        do {
            let next = try documentIncludingDraft()
            diskData = try LibraryRepository.save(next, to: libraryURL, expected: diskData)
            document = next; selectedAlias = game.alias; original = game
            return true
        } catch { show(error); return false }
    }
    func discardEdits() { draft = original }
    func deleteGame() {
        guard !launcher.isRunning, let alias = selectedAlias else { return }
        let alert = NSAlert()
        alert.messageText = L("Remove \(draft?.title ?? alias) from the library?")
        alert.informativeText = L("This only removes the launcher entry. No installed games or save files are deleted. Unsaved edits to this entry will be discarded.")
        alert.addButton(withTitle: L("Remove Entry")); alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            var next = document
            next.games.removeAll { $0.alias == alias }
            diskData = try LibraryRepository.save(next, to: libraryURL, expected: diskData)
            document = next; selectedAlias = nil; draft = nil; original = nil
        } catch { show(error) }
    }
    func reload() {
        guard !launcher.isRunning, resolveEdits() else { return }
        do { try load(libraryURL) } catch { show(error) }
    }
    func openLibrary() {
        guard !launcher.isRunning, resolveEdits() else { return }
        let panel = NSOpenPanel()
        panel.title = L("Open Game Library"); panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try load(url) } catch { show(error) }
    }
    func exportLibrary() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard loaded else { return }
        do {
            let next = try documentIncludingDraft()
            let bytes = try LibraryRepository.encode(next)
            let panel = NSSavePanel(); panel.nameFieldStringValue = "games-export.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.standardizedFileURL.resolvingSymlinksInPath() != libraryURL.standardizedFileURL.resolvingSymlinksInPath() else {
                throw LibraryError(L("Choose a different file for export. Use Save to update the open library safely."))
            }
            try bytes.write(to: url, options: .atomic)
        } catch { show(error) }
    }
    func exportRacketLibrary() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard loaded, !exportingRacket else { return }
        do {
            let bytes = try LibraryRepository.encode(documentIncludingDraft())
            let panel = NSSavePanel()
            panel.title = L("Export games.rkt")
            panel.message = L("Choose a new file. Includes current edits, but not notes or extra JSON fields. Requires your existing types.rkt; no backend is installed or replaced.")
            panel.nameFieldStringValue = "games.rkt"
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            let backend = try Resources.url("Backend")
            let play = backend.appendingPathComponent("play")
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let input = temporary.appendingPathComponent("games.json")
            let output = temporary.appendingPathComponent("games.rkt")
            let environment = LaunchController.environment(library: input,
                script: backend.appendingPathComponent("main.rkt"), racket: preferences.racketPath)
            exportingRacket = true
            Task {
                defer { exportingRacket = false }
                do {
                    try await Task.detached(priority: .userInitiated) {
                        let fm = FileManager.default
                        try fm.createDirectory(at: temporary, withIntermediateDirectories: false)
                        defer { try? fm.removeItem(at: temporary) }
                        try bytes.write(to: input, options: .withoutOverwriting)
                        let process = Process(); let pipe = Pipe()
                        process.executableURL = URL(fileURLWithPath: "/bin/sh")
                        process.arguments = [play.path, "--export-racket", output.path]
                        process.environment = environment
                        process.standardInput = FileHandle.nullDevice
                        process.standardOutput = pipe; process.standardError = pipe
                        try process.run()
                        try? pipe.fileHandleForWriting.close()
                        let diagnostics = pipe.fileHandleForReading.readDataToEndOfFile()
                        process.waitUntilExit()
                        try? pipe.fileHandleForReading.close()
                        guard process.terminationStatus == 0 else {
                            throw LibraryError(L("Racket export failed: ") + String(decoding: diagnostics, as: UTF8.self))
                        }
                        // Even a confirmed Save-panel replacement is refused: this
                        // export must not overwrite the user's working scripts.
                        try Data(contentsOf: output).write(to: destination, options: .withoutOverwriting)
                    }.value
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                } catch { show(error) }
            }
        } catch { show(error) }
    }
    func launch(infoOnly: Bool = false) {
        guard !launcher.isRunning, resolveEdits(), let game = draft else { return }
        do {
            try game.validate()
            guard try Data(contentsOf: libraryURL) == diskData else { throw LibraryError(L("The library changed on disk. Reload it before launching.")) }
            if !infoOnly && game.exeName.trimmingCharacters(in: .whitespaces).isEmpty {
                throw LibraryError(L("Set the process/executable name before launching, so the backend can monitor the game."))
            }
            if !infoOnly && !game.platform.hasPrefix("steam-") && game.storeID.trimmingCharacters(in: .whitespaces).isEmpty {
                throw LibraryError(L("Set the store ID or executable path before launching."))
            }
            let bundled = try Resources.url("Backend")
            let backend = preferences.backendDirectory.isEmpty ? bundled : URL(fileURLWithPath: (preferences.backendDirectory as NSString).expandingTildeInPath)
            let script = backend.appendingPathComponent("main.rkt")
            guard FileManager.default.fileExists(atPath: script.path) else { throw LibraryError(L("No main.rkt in the selected backend folder.")) }
            let winePath = try WineEnvironment.resolvedPath(preferences.wineEnvironmentPath)
            if game.usesWine && !infoOnly {
                _ = try WineEnvironment.readableURL(winePath)
                guard (try String(contentsOf: backend.appendingPathComponent("wine.rkt"), encoding: .utf8)).contains("live-wine-env-v1") else {
                    throw LibraryError(L("Select the updated bundled backend to use the Wine environment setting."))
                }
            }
            try launcher.start(play: bundled.appendingPathComponent("play"), script: script,
                               library: libraryURL, racket: preferences.racketPath,
                               alias: game.alias, title: game.title, infoOnly: infoOnly, nativeDisplay: preferences.nativeDisplay, nativeInput: preferences.nativeInput, wineEnvironmentPath: winePath)
            if !infoOnly && preferences.hideOnLaunch { NSApp.hide(nil) }
        } catch { show(error) }
    }
    func createLauncher() {
        guard !launcher.isRunning, resolveEdits(), let game = draft else { return }
        do {
            try game.validate()
            guard try Data(contentsOf: libraryURL) == diskData else {
                throw LibraryError(L("The library changed on disk. Reload it before creating a launcher."))
            }
            let bundled = try Resources.url("Backend")
            let backend = preferences.backendDirectory.isEmpty ? bundled : URL(fileURLWithPath: (preferences.backendDirectory as NSString).expandingTildeInPath)
            let executable = try Resources.url("GameRunner")
            var identifier = LauncherNaming.identifier(username: NSUserName(), title: game.title, alias: game.alias)
            if document.games.contains(where: { $0.alias != game.alias && LauncherNaming.identifier(username: NSUserName(), title: $0.title, alias: $0.alias) == identifier }) {
                identifier += "-" + game.alias.replacingOccurrences(of: "_", with: "-").lowercased()
            }
            launcherExport = LauncherExportRequest(game: game, library: libraryURL, backend: backend,
                play: bundled.appendingPathComponent("play"), executable: executable,
                racket: (preferences.racketPath as NSString).expandingTildeInPath, identifier: identifier,
                nativeDisplay: preferences.nativeDisplay, nativeInput: preferences.nativeInput, wineEnvironmentPath: try WineEnvironment.resolvedPath(preferences.wineEnvironmentPath))
        } catch { show(error) }
    }
    func stop() {
        guard launcher.isRunning else { return }
        let alert = NSAlert()
        alert.messageText = L("Stop the current launcher session?")
        alert.informativeText = L("This uses your existing play cleanup, which can close Wine sessions and helper processes beyond this game. Save in the game first.")
        alert.addButton(withTitle: L("Stop Session")); alert.addButton(withTitle: L("Keep Running"))
        if alert.runModal() == .alertFirstButtonReturn { launcher.stop() }
    }
    func mayQuit() -> Bool {
        if launcher.isRunning {
            let alert = NSAlert()
            alert.messageText = L("A launcher session is still running.")
            alert.informativeText = L("Finish the game or use Stop Session before quitting. The app needs to keep supervising cleanup.")
            alert.addButton(withTitle: L("Keep App Running"))
            alert.runModal()
            return false
        }
        return resolveEdits()
    }
}
