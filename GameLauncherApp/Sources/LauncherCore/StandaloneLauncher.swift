import Foundation
import CoreGraphics

public enum LauncherPresentation: String, Codable, CaseIterable, Sendable {
    case progress, text, none
    public var label: String {
        switch self {
        case .progress: return L("Progress bar + current message")
        case .text: return L("Text output")
        case .none: return L("No window")
        }
    }
    public var showsWindow: Bool { self != .none }
}

public struct StandaloneConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var alias: String
    public var title: String
    public var libraryPath: String
    public var racketPath: String
    public var presentation: LauncherPresentation
    public var wineEnvironmentPath: String? // File path only; contents stay live.
    public var nativeInput: Bool? // Missing means legacy cliclick/Cursorcerer.
    public var nativeDisplay: Bool? // Missing in older exports means RDM.

    public init(alias: String, title: String, libraryPath: String, racketPath: String,
                presentation: LauncherPresentation, nativeDisplay: Bool? = nil, nativeInput: Bool? = nil, wineEnvironmentPath: String? = nil) {
        self.nativeInput = nativeInput
        self.wineEnvironmentPath = wineEnvironmentPath
        self.alias = alias; self.title = title; self.libraryPath = libraryPath
        self.racketPath = racketPath; self.presentation = presentation; self.nativeDisplay = nativeDisplay
    }
    public func validate() throws {
        _ = try WineEnvironment.resolvedPath(wineEnvironmentPath)
        guard schemaVersion == 1 else { throw LibraryError(L("Unsupported standalone launcher version.")) }
        guard alias.rangeOfCharacter(from: .controlCharacters) == nil, alias.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil else {
            throw LibraryError(L("Invalid game alias in launcher configuration."))
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw LibraryError(L("The launcher name must be nonempty text without control characters."))
        }
        guard libraryPath.hasPrefix("/"), !libraryPath.contains("\0"),
              racketPath.isEmpty || (racketPath.hasPrefix("/") && !racketPath.contains("\0")) else {
            throw LibraryError(L("Library and explicit Racket paths must be absolute. Leave Racket blank for automatic discovery."))
        }
    }
    public static func load(resources: URL) throws -> StandaloneConfiguration {
        let data = try Data(contentsOf: resources.appendingPathComponent("launcher.json"))
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }
}

public enum LauncherNaming {
    private static func component(_ text: String, fallback: String) -> String {
        let ascii = text.folding(options: [.diacriticInsensitive, .widthInsensitive],
                                 locale: Locale(identifier: "en_US_POSIX")).lowercased()
        let scalars = ascii.unicodeScalars.filter {
            (97...122).contains($0.value) || (48...57).contains($0.value) || $0.value == 45
        }
        let result = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? fallback : result
    }
    public static func identifier(username: String, title: String, alias: String) -> String {
        "org.\(component(username, fallback: "user")).\(component(title, fallback: component(alias, fallback: "game")))"
    }
    public static func validateIdentifier(_ identifier: String) throws {
        guard identifier.utf8.count <= 255, identifier.rangeOfCharacter(from: .controlCharacters) == nil,
              identifier.range(of: "^[A-Za-z0-9][A-Za-z0-9-]*(\\.[A-Za-z0-9][A-Za-z0-9-]*)+$",
                               options: .regularExpression) != nil else {
            throw LibraryError(L("Use a unique reverse-DNS identifier, such as org.username.gamename. Only ASCII letters, digits, dots and hyphens are allowed; no spaces or colons."))
        }
    }
    public static func filename(title: String, alias: String) -> String {
        let cleaned = title.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return (cleaned.isEmpty ? alias : cleaned) + ".app"
    }
}

public struct LauncherExportOptions: Sendable {
    public var configuration: StandaloneConfiguration
    public var identifier: String
    public var icon: URL?
    public init(configuration: StandaloneConfiguration, identifier: String, icon: URL?) {
        self.configuration = configuration; self.identifier = identifier; self.icon = icon
    }
}

public enum LauncherBundleBuilder {
    // Build in a sibling temporary folder; never replace an existing app, even if
    // signing fails or another export reaches the destination first.
    public static func build(at destination: URL, options: LauncherExportOptions,
                             executable: URL, backend: URL, play: URL,
                             finalize: (URL) throws -> Void) throws {
        try options.configuration.validate()
        try LauncherNaming.validateIdentifier(options.identifier)
        let fm = FileManager.default
        guard destination.pathExtension.lowercased() == "app" else { throw LibraryError(L("Choose an .app destination.")) }
        guard !fm.fileExists(atPath: destination.path),
              (try? fm.destinationOfSymbolicLink(atPath: destination.path)) == nil else {
            throw LibraryError(L("An item already exists at this destination. Choose another name; existing apps are never overwritten."))
        }
        guard fm.isExecutableFile(atPath: executable.path) else {
            throw LibraryError(L("The native GameRunner executable is missing. Build the editor with build-macos.sh first."))
        }
        for name in ["main.rkt", "library.rkt"] {
            guard fm.isReadableFile(atPath: backend.appendingPathComponent(name).path) else {
                throw LibraryError(L("Missing \(name) in the selected backend."))
            }
        }
        if options.configuration.nativeInput == true {
            for name in ["focus.rkt", "native-input.rkt"] {
                guard (try String(contentsOf: backend.appendingPathComponent(name), encoding: .utf8)).contains("native-input-owner-v1") else {
                    throw LibraryError(L("Native input export requires the updated bundled backend."))
                }
            }
        }
        if options.configuration.nativeDisplay == true {
            for source in [play, backend.appendingPathComponent("display.rkt")] {
                guard (try String(contentsOf: source, encoding: .utf8)).contains("native-display-owner-v1") else {
                    throw LibraryError(L("Native display export requires the updated play and display.rkt. Select the bundled backend or use RDM."))
                }
            }
        }
        if options.configuration.wineEnvironmentPath != nil {
            for name in ["wine-launch.sh", "wine-cleanup.sh"] {
                guard fm.isReadableFile(atPath: backend.appendingPathComponent(name).path) else {
                    throw LibraryError(L("Updated Wine backend required: missing \(name). Select the bundled backend."))
                }
            }
            guard (try String(contentsOf: backend.appendingPathComponent("wine.rkt"), encoding: .utf8)).contains("live-wine-env-v1") else {
                throw LibraryError(L("The selected backend does not support the live Wine environment setting."))
            }
        }
        let iconData: Data?
        if let icon = options.icon {
            let data = try Data(contentsOf: icon)
            guard icon.pathExtension.lowercased() == "icns", data.count >= 8,
                  data.prefix(4) == Data("icns".utf8),
                  data[4..<8].reduce(UInt32(0), { ($0 << 8) | UInt32($1) }) == data.count else {
                throw LibraryError(L("Select a valid Apple .icns file."))
            }
            iconData = data
        } else { iconData = nil }

        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".launcher-export-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        let app = staging.appendingPathComponent(destination.lastPathComponent, isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let backendCopy = resources.appendingPathComponent("Backend", isDirectory: true)
        try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fm.createDirectory(at: backendCopy, withIntermediateDirectories: true)
        try L10n.copyResources(to: resources)
        let runner = macOS.appendingPathComponent("GameRunner")
        try fm.copyItem(at: executable, to: runner)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runner.path)
        // Snapshot Racket source and the two bundled adapters, not caches, libraries
        // or the live wine_env.sh. Its configured file path stays external.
        guard let paths = fm.enumerator(at: backend, includingPropertiesForKeys: [.isDirectoryKey],
                                        options: [.skipsHiddenFiles]) else {
            throw LibraryError(L("Could not enumerate the backend folder."))
        }
        let basePath = backend.standardizedFileURL.path + "/"
        for case let source as URL in paths {
            let directory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            if directory && ["compiled", "tests", "dist"].contains(source.lastPathComponent) {
                paths.skipDescendants(); continue
            }
            guard !directory else { continue }
            guard source.standardizedFileURL.path.hasPrefix(basePath) else { throw LibraryError(L("Invalid backend source path.")) }
            let relative = String(source.standardizedFileURL.path.dropFirst(basePath.count))
            let helper = ["wine-launch.sh", "wine-cleanup.sh", "blackbars", "runtime_loader", "libRuntimeRosettax87"].contains(relative)
            guard source.pathExtension == "rkt" || helper else { continue }
            let target = backendCopy.appendingPathComponent(relative)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contentsOf: source).write(to: target) // Dereference individual source-file symlinks.
            if helper { try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path) }
        }
        try Data(contentsOf: play).write(to: backendCopy.appendingPathComponent("play"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(options.configuration).write(to: resources.appendingPathComponent("launcher.json"))
        var plist: [String: Any] = [
            "CFBundleExecutable": "GameRunner", "CFBundleIdentifier": options.identifier,
            "CFBundleName": options.configuration.title, "CFBundleDisplayName": options.configuration.title,
            "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.4.2", "CFBundleVersion": "15",
            "CFBundleDevelopmentRegion": "en", "CFBundleLocalizations": ["en", "pt-BR"],
            "LSMinimumSystemVersion": "13.0", "LSUIElement": true,
            "NSHighResolutionCapable": true, "NSPrincipalClass": "NSApplication",
            "NSAppleEventsUsageDescription": "Run the configured game launcher, manage display settings and focus the game."
        ]
        if let data = iconData {
            try data.write(to: resources.appendingPathComponent("GameIcon.icns"))
            plist["CFBundleIconFile"] = "GameIcon.icns"
        }
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        try Data("APPL????".utf8).write(to: contents.appendingPathComponent("PkgInfo"))
        try finalize(app) // Sign and verify before publishing the app.
        try fm.moveItem(at: app, to: destination)
    }
}

public enum LauncherWindowPlacement {
    // AppKit coordinates are points, with a bottom-left origin. Center on the
    // display itself (not an asymmetric Dock inset), then keep the panel visible.
    public static func topLeft(screenFrame: CGRect, visibleFrame: CGRect, windowWidth: CGFloat) -> CGPoint {
        let centeredX = screenFrame.midX - windowWidth / 2
        let rightmostX = max(visibleFrame.minX, visibleFrame.maxX - windowWidth)
        let x = min(max(centeredX, visibleFrame.minX), rightmostX)
        return CGPoint(x: x, y: visibleFrame.maxY - 4)
    }
}
