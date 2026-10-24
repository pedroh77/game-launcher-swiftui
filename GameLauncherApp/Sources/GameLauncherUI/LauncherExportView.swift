import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LauncherCore

struct LauncherExportRequest: Identifiable {
    let id = UUID()
    let game: GameRecord
    let library: URL
    let backend: URL
    let play: URL
    let executable: URL
    let racket: String
    let identifier: String
    let nativeDisplay: Bool
    let nativeInput: Bool
    let wineEnvironmentPath: String
}

private enum LauncherSigning {
    static func sign(_ app: URL) throws {
        try run(["--force", "--sign", "-", app.path])
        try run(["--verify", "--deep", "--strict", app.path])
    }
    private static func run(_ arguments: [String]) throws {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        try process.run()
        try? pipe.fileHandleForWriting.close()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? pipe.fileHandleForReading.close()
        guard process.terminationStatus == 0 else {
            throw LibraryError(L("Could not sign/verify the launcher: ") + String(decoding: output, as: UTF8.self))
        }
    }
}

@MainActor
struct LauncherExportView: View {
    let request: LauncherExportRequest
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var identifier: String
    @State private var presentation = LauncherPresentation.progress
    @State private var icon: URL?
    @State private var exporting = false
    @State private var created: URL?
    @State private var error: String?

    init(request: LauncherExportRequest) {
        self.request = request
        _name = State(initialValue: request.game.title)
        _identifier = State(initialValue: request.identifier)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Create Game Launcher")).font(.title2).bold()
            Text(L("A native .app for \(request.game.title). No Platypus installation is needed."))
                .font(.callout).foregroundStyle(.secondary)
            Form {
                TextField(L("App name"), text: $name)
                TextField(L("Bundle identifier"), text: $identifier)
                Picker(L("Output"), selection: $presentation) {
                    ForEach(LauncherPresentation.allCases, id: \.self) { style in Text(style.label).tag(style) }
                }
                Text(L("Display manager: ") + (request.nativeDisplay ? L("Native (built-in display; test first)") : L("RDM (existing behavior)")))
                Text(request.nativeInput ? L("Input: native clicks and cursor (Accessibility required)") : L("Input: legacy cliclick and Cursorcerer"))
                Text(L("Live Wine environment: \(request.wineEnvironmentPath)")).font(.caption).textSelection(.enabled)
                HStack {
                    if let icon = icon, let image = NSImage(contentsOf: icon) {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "app.dashed").font(.system(size: 36)).frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading) {
                        Text(icon?.lastPathComponent ?? L("Generic application icon")).lineLimit(1)
                        HStack {
                            Button(L("Choose .icns…"), action: chooseIcon)
                            if icon != nil { Button(L("Clear")) { icon = nil } }
                        }
                    }
                }
            }.disabled(exporting || created != nil)
            Text(L("Compact window below the menu bar · Does not request focus · Quits when the session finishes"))
                .font(.caption)
            Text(L("Uses your live library at \(request.library.path). Game-setting edits apply next launch. The Racket backend is copied into the app; external Wine scripts stay in place."))
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Text(L("Cancel (or closing the window) runs the existing play cleanup and can end other Wine sessions. Use one launcher session at a time."))
                .font(.caption).foregroundStyle(.orange)
            if let error = error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            if let created = created {
                Text(L("Created: \(created.path)")).font(.caption).textSelection(.enabled)
            }
            HStack {
                if exporting { ProgressView().controlSize(.small); Text(L("Creating and signing…")).font(.caption) }
                Spacer()
                Button(created == nil ? L("Cancel") : L("Done")) { dismiss() }.disabled(exporting)
                if let created = created {
                    Button(L("Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([created]) }
                } else {
                    Button(L("Create…"), action: create).disabled(exporting)
                }
            }
        }
        .padding(24).frame(width: 720, height: 720)
        .interactiveDismissDisabled(exporting)
    }
    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.title = L("Choose a game icon")
        panel.allowedContentTypes = [UTType(filenameExtension: "icns") ?? .data]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            guard NSImage(contentsOf: url) != nil else { error = L("macOS could not read this icon."); return }
            icon = url; error = nil
        }
    }
    private func create() {
        do {
            let configuration = StandaloneConfiguration(alias: request.game.alias, title: name,
                libraryPath: request.library.path, racketPath: request.racket, presentation: presentation, nativeDisplay: request.nativeDisplay, nativeInput: request.nativeInput, wineEnvironmentPath: request.wineEnvironmentPath)
            try configuration.validate()
            try LauncherNaming.validateIdentifier(identifier)
            let options = LauncherExportOptions(configuration: configuration, identifier: identifier, icon: icon)
            let panel = NSSavePanel()
            panel.title = L("Save Game Launcher")
            panel.message = L("Choose a new .app name. Existing apps are never overwritten.")
            panel.nameFieldStringValue = LauncherNaming.filename(title: name, alias: request.game.alias)
            panel.allowedContentTypes = [.applicationBundle]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            let executable = request.executable, backend = request.backend, play = request.play
            exporting = true; error = nil
            Task {
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try LauncherBundleBuilder.build(at: destination, options: options, executable: executable,
                                                        backend: backend, play: play, finalize: LauncherSigning.sign)
                    }.value
                    created = destination
                } catch { self.error = error.localizedDescription }
                exporting = false
            }
        } catch { self.error = error.localizedDescription }
    }
}
