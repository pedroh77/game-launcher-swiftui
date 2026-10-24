import Foundation

public enum WineEnvironment {
    public static let environmentKey = "GAME_LAUNCHER_WINE_ENV"
    public static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/libexec/wine_env.sh").path
    }
    public static func resolvedPath(_ path: String?) throws -> String {
        let value = path.flatMap { $0.isEmpty ? nil : $0 } ?? defaultPath
        guard value.hasPrefix("/"), value.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw LibraryError(L("The Wine environment script needs an absolute path including its filename."))
        }
        return value
    }
    public static func readableURL(_ path: String?) throws -> URL {
        let url = URL(fileURLWithPath: try resolvedPath(path))
        guard FileManager.default.isReadableFile(atPath: url.path),
              (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw LibraryError(L("Wine environment script is missing or unreadable: \(url.path)"))
        }
        return url
    }
}
