import SwiftUI
import AppKit
import LauncherCore

@MainActor
struct GameEditor: View {
    @Binding var game: GameRecord

    private func optional(_ key: String) -> Binding<String> {
        Binding(get: { game.optionalText(key) }, set: { game.setOptionalText(key, $0) })
    }
    private func custom(_ key: String, _ fallback: Double) -> Binding<Double> {
        Binding(get: { game.customNumber(key, default: fallback) }, set: { game.setCustomNumber(key, $0) })
    }
    private var focusEnabled: Binding<Bool> {
        Binding(get: { game.focusDelay != nil }, set: { game.focusDelay = $0 ? 6 : nil })
    }
    private var delay: Binding<Double> {
        Binding(get: { game.focusDelay ?? 6 }, set: { game.focusDelay = $0 })
    }
    private var display: Binding<String> {
        Binding(get: { game.displayMode }, set: {
            game.displayMode = $0
            if $0 == "custom" && game.values["customDisplay"] == nil {
                game.setCustomNumber("width", 2560)
            }
        })
    }
    var body: some View {
        Form {
            generalSection
            if game.usesWine { wineSection }
            displaySection
            focusSection
            advancedSection
        }
        .formStyle(.grouped)
    }

    private var generalSection: some View {
        Section(L("General & Launch")) {
            TextField(L("Title"), text: $game.title)
            TextField(L("Alias"), text: $game.alias)
                .help(L("The name used by play, for example darksouls. Letters, digits, _ and - only."))
            Picker(L("Launch method"), selection: $game.runner) {
                ForEach(GameRecord.runners, id: \.0) { value, label in Text(label).tag(value) }
            }
            if game.platform == "direct" {
                HStack {
                    TextField(L("Executable path / Wine command"), text: $game.storeID)
                    Button(L("Browse…")) { browse(binding: $game.storeID, directories: false, insidePackages: true) }
                }
                Text(L("For native apps, select the executable inside .app/Contents/MacOS, not the .app folder."))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField(game.platform.hasPrefix("steam-") ? L("Steam App ID") : L("Store game ID"), text: $game.storeID)
            }
            TextField(L("Process name to monitor"), text: $game.exeName)
                .help(L("The actual process, such as Afterimage-Win64-Shipping.exe or Game.macOS. This is separate from the store ID."))
            if game.platform.hasPrefix("steam-") && (game.storeID.isEmpty || game.storeID == "0") {
                Text(L("This legacy entry has an empty/zero Steam ID. It was preserved during import; verify it before launching."))
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var wineSection: some View {
        Section(L("Wine / Sikarugir")) {
            HStack {
                TextField(L("Wrapper"), text: optional("wrapper"))
                Menu(L("Presets")) {
                    Button("Steam_SK.app") { game.setOptionalText("wrapper", "Steam_SK.app") }
                    Button("Steam_DXVK.app") { game.setOptionalText("wrapper", "Steam_DXVK.app") }
                }.fixedSize()
                Button(L("Browse…")) { browse(binding: optional("wrapper"), directories: true) }
            }
            Text(L("A wrapper name is resolved under ~/Applications. Absolute .app or Contents paths also work."))
                .font(.caption).foregroundStyle(.secondary)
            Picker(L("Renderer"), selection: $game.renderer) {
                ForEach(GameRecord.renderers, id: \.self) { Text($0 == "none" ? L("None") : $0).tag($0) }
            }
            Toggle(L("Enable Rosetta x87 JIT when available"), isOn: $game.rosettaX87)
            TextField(L("DLL overrides"), text: optional("dllOverrides"))
                .help(L("For example dxgi=n,b or d3d9=n,b;d3d11=d. Blank means no override."))
            if ["epic-wine", "gog-wine", "amazon"].contains(game.platform) {
                Text(L("All Wine launches use the bundled adapter and your selected live wine_env.sh. A separate wine_x87.sh is no longer required."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if game.optionalText("wrapper") == "Contents" {
                Text(L("Imported wrapper is just “Contents”. Verify the intended wrapper location; this app has not guessed a replacement."))
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var displaySection: some View {
        Section(L("Display")) {
            Picker(L("Profile"), selection: display) {
                ForEach(GameRecord.displays, id: \.0) { value, label in Text(label).tag(value) }
            }
            if game.displayMode == "custom" {
                HStack {
                    TextField(L("Width"), value: custom("width", 2560), format: .number)
                    TextField(L("Height"), value: custom("height", 1600), format: .number)
                }
                Picker(L("Display scale"), selection: custom("scale", 1)) {
                    Text(L("1×")).tag(1.0); Text(L("2× / HiDPI")).tag(2.0)
                }
                TextField(L("Pointer scale"), value: custom("pointerScale", 2), format: .number)
            }
            Toggle(L("Use black bars helper"), isOn: $game.blackbars)
                .disabled(game.displayMode == "off")
            Text(L("Uses the display manager selected in Settings: native Swift switching or legacy RDM. Both preserve the 1920×1080 skip policy and restore 1440×900 at 2× / pointer 1×. Black bars run only when display switching is active."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var focusSection: some View {
        Section(L("Focus & Cursor")) {
            Toggle(L("Use delayed focus clicks"), isOn: focusEnabled)
            if game.focusDelay != nil {
                TextField(L("Delay after process appears (seconds)"), value: delay, format: .number)
                TextField(L("Click coordinates (x,y)"), text: optional("focusCoords"))
                    .help(L("Blank uses the existing default: 1919,1079."))
                Text(L("Preserves your existing sequence: wait for process, delay, click twice, hide the cursor, wait 3 seconds, click again. Settings selects native input or legacy cliclick/Cursorcerer. Native coordinates must fit the active display."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var advancedSection: some View {
        Section(L("Advanced")) {
            if game.platform == "direct" || game.platform.hasPrefix("gog-") {
                pathField(L("Game / working directory"), key: "gameDir")
            }
            if game.platform.hasPrefix("gog-") { pathField(L("Save directory for GOG sync"), key: "saveDir") }
            if game.platform == "steam-wine" {
                TextField(L("Custom PowerShell script"), text: optional("ps1Script"))
                Text(L("A filename under C:/Scripts, such as princeof.ps1. Blank uses steam_runner.ps1."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField(L("Notes"), text: optional("notes"), axis: .vertical)
                .lineLimit(2...5)
            Text(L("Prefer absolute directory paths. Legacy $HOME/ and $WRAPPER/ expansions are allowed where the runner supports them; relative GOG Wine save paths are under drive_c. Double quotes, backticks, backslashes and other $ substitutions are rejected by the legacy shell boundary. Use forward slashes."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func pathField(_ title: String, key: String) -> some View {
        HStack {
            TextField(title, text: optional(key))
            Button(L("Browse…")) { browse(binding: optional(key), directories: true) }
        }
    }
    private func browse(binding: Binding<String>, directories: Bool, insidePackages: Bool = false) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directories
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = insidePackages
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }
}
