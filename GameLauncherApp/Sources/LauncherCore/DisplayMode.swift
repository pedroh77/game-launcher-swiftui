import Foundation

public struct DisplayModeSpec: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let scale: Int
    public init(width: Int, height: Int, scale: Int) {
        self.width = width; self.height = height; self.scale = scale
    }
    public static let restore = DisplayModeSpec(width: 1440, height: 900, scale: 2)
    public static let presets: [String: DisplayModeSpec] = [
        "2560x1600": .init(width: 2560, height: 1600, scale: 1),
        "2048x1280": .init(width: 2048, height: 1280, scale: 1),
        "1680x1050": .init(width: 1680, height: 1050, scale: 2),
        "1920x1200": .init(width: 1920, height: 1200, scale: 1),
        "1280x800": .init(width: 1280, height: 800, scale: 2)
    ]
    public var label: String { L("\(width)×\(height) at \(scale)×") }
    public var backendValue: String { "\(width),\(height),\(scale)" }
    public static func forGame(_ game: GameRecord) throws -> DisplayModeSpec? {
        try game.validate()
        if game.displayMode == "off" { return nil }
        if let mode = presets[game.displayMode] { return mode }
        guard game.displayMode == "custom",
              let width = Int(exactly: game.customNumber("width", default: 0)),
              let height = Int(exactly: game.customNumber("height", default: 0)),
              let scale = Int(exactly: game.customNumber("scale", default: 0)),
              width > 0, height > 0, [1, 2].contains(scale),
              width <= Int.max / scale, height <= Int.max / scale else {
            throw LibraryError(L("Invalid native display profile."))
        }
        return .init(width: width, height: height, scale: scale)
    }
}
