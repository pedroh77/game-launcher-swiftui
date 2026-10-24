import Foundation

// JSON-backed records preserve unknown fields when a newer backend adds options.
public enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var number: Double? { if case .number(let v) = self { return v }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var object: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
}

public struct LibraryError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct GameRecord: Codable, Equatable, Identifiable {
    public var values: [String: JSONValue]
    public var id: String { alias }
    public init(values: [String: JSONValue]) { self.values = values }
    public init(from decoder: Decoder) throws { values = try [String: JSONValue](from: decoder) }
    public func encode(to encoder: Encoder) throws { try values.encode(to: encoder) }

    public static func new(alias: String) -> GameRecord {
        GameRecord(values: [
            "alias": .string(alias), "title": .string(L("New Game")),
            "platform": .string("steam-wine"), "id": .string(""), "exeName": .string(""),
            "wrapper": .string("Steam_SK.app"), "renderer": .string("d3dmetal"),
            "rosettaX87": .bool(true), "blackbars": .bool(false),
            "displayMode": .string("2560x1600"), "focusDelay": .number(6),
            "focusCoords": .null, "dllOverrides": .null, "gameDir": .null,
            "saveDir": .null, "ps1Script": .null
        ])
    }
    private func text(_ key: String, _ fallback: String = "") -> String { values[key]?.string ?? fallback }
    public var alias: String { get { text("alias") } set { values["alias"] = .string(newValue) } }
    public var title: String { get { text("title") } set { values["title"] = .string(newValue) } }
    public var platform: String { get { text("platform") } set { values["platform"] = .string(newValue) } }
    public var exeName: String { get { text("exeName") } set { values["exeName"] = .string(newValue) } }
    public var renderer: String { get { text("renderer", "d3dmetal") } set { values["renderer"] = .string(newValue) } }
    public var displayMode: String { get { text("displayMode", "2560x1600") } set { values["displayMode"] = .string(newValue) } }
    public var blackbars: Bool { get { values["blackbars"]?.bool ?? false } set { values["blackbars"] = .bool(newValue) } }
    public var rosettaX87: Bool { get { values["rosettaX87"]?.bool ?? true } set { values["rosettaX87"] = .bool(newValue) } }
    public var storeID: String {
        get {
            if let s = values["id"]?.string { return s }
            if let n = values["id"]?.number, let i = Int64(exactly: n) { return String(i) }
            return ""
        }
        set { values["id"] = .string(newValue) }
    }
    public var focusDelay: Double? {
        get { values["focusDelay"]?.number }
        set { values["focusDelay"] = newValue.map(JSONValue.number) ?? .null }
    }
    public func optionalText(_ key: String) -> String { text(key) }
    public mutating func setOptionalText(_ key: String, _ value: String) {
        values[key] = value.isEmpty ? .null : .string(value)
    }
    public var usesWine: Bool {
        platform.hasSuffix("-wine") || platform == "amazon" ||
        (["direct", "epic"].contains(platform) && values["wrapper"]?.string != nil)
    }
    public var runner: String {
        get {
            if platform == "direct" || platform == "epic" {
                return platform + (usesWine ? "-wine" : "-mac")
            }
            return platform
        }
        set {
            platform = newValue.hasPrefix("direct-") ? "direct" : newValue
            if newValue.hasSuffix("-wine") || newValue == "amazon" {
                if optionalText("wrapper").isEmpty { values["wrapper"] = .string("Steam_SK.app") }
            } else { values["wrapper"] = .null }
        }
    }
    public func customNumber(_ key: String, default fallback: Double) -> Double {
        values["customDisplay"]?.object?[key]?.number ?? fallback
    }
    public mutating func setCustomNumber(_ key: String, _ value: Double) {
        var p = values["customDisplay"]?.object ?? [
            "width": .number(2560), "height": .number(1600),
            "scale": .number(1), "pointerScale": .number(2)
        ]
        p[key] = .number(value)
        values["customDisplay"] = .object(p)
    }
    public static let runners: [(String, String)] = [
        ("steam-wine", L("Steam · Wine")), ("steam-mac", L("Steam · macOS")),
        ("epic-wine", L("Epic / Legendary · Wine")), ("epic-mac", L("Epic / Legendary · macOS")),
        ("gog-wine", L("GOG · Wine")), ("gog-mac", L("GOG · macOS")),
        ("amazon", L("Amazon / Nile · Wine")),
        ("direct-wine", L("Direct executable · Wine")), ("direct-mac", L("Direct executable · macOS"))
    ]
    public static let renderers = ["d3dmetal", "dxvk", "dxmt", "mtld3d", "d9mt", "none"]
    public static let displays: [(String, String)] = [
        ("off", L("Keep current display")), ("2560x1600", L("2560 × 1600 · 1× / pointer 2×")),
        ("2048x1280", L("2048 × 1280 · 1× / pointer 2×")),
        ("1680x1050", L("1680 × 1050 · HiDPI / pointer 1.5×")),
        ("1920x1200", L("1920 × 1200 · 1× / pointer 2×")),
        ("1280x800", L("1280 × 800 · HiDPI / pointer 1×")), ("custom", L("Custom profile…"))
    ]
    public var runnerLabel: String { Self.runners.first { $0.0 == runner }?.1 ?? platform }

    public func validate() throws {
        func fail(_ text: String) throws { throw LibraryError(L("\(alias.isEmpty ? L("Game") : alias): \(text)")) }
        func matches(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }
        guard matches(alias, "^[A-Za-z0-9][A-Za-z0-9_-]*$") else { try fail(L("Alias may contain letters, digits, _ and -.")); return }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { try fail(L("Title is required.")); return }
        guard ["steam-mac", "steam-wine", "gog-mac", "gog-wine", "epic-mac", "epic-wine", "epic", "amazon", "direct"].contains(platform),
              Self.runners.contains(where: { $0.0 == runner }) else { try fail(L("Unsupported runner: \(runner).")); return }
        guard values["exeName"]?.string != nil else { try fail(L("exeName must be a string.")); return }
        guard values["id"]?.string != nil || (values["id"]?.number.map { $0 >= 0 && Int64(exactly: $0) != nil } ?? false) else {
            try fail(L("ID must be a string or a nonnegative integer.")); return
        }
        if platform.hasPrefix("steam-"), !matches(storeID, "^[0-9]*$") { try fail(L("Steam ID must contain digits only.")) }
        if usesWine && optionalText("wrapper").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try fail(L("A Wine wrapper is required.")) }
        guard Self.renderers.contains(renderer) else { try fail(L("Unknown renderer.")); return }
        guard Self.displays.contains(where: { $0.0 == displayMode }) else { try fail(L("Unknown display profile.")); return }
        for key in ["blackbars", "rosettaX87"] where values[key] != nil && values[key]?.bool == nil { try fail(L("\(key) must be a boolean.")) }
        for key in ["renderer", "displayMode"] where values[key] != nil && values[key]?.string == nil { try fail(L("\(key) must be a string.")) }
        for key in ["wrapper", "dllOverrides", "gameDir", "saveDir", "ps1Script", "focusCoords"] {
            if let value = values[key], value != .null, value.string == nil { try fail(L("\(key) must be text or null.")) }
        }
        if let v = values["focusDelay"], v != .null {
            guard let n = v.number, n.isFinite, n >= 0 else { try fail(L("Focus delay must be a nonnegative number.")); return }
        }
        if let coords = values["focusCoords"]?.string, !matches(coords, "^-?[0-9]+,-?[0-9]+$") { try fail(L("Focus coordinates must be integers in x,y format.")) }
        if displayMode == "custom" {
            guard let p = values["customDisplay"]?.object else { try fail(L("Custom display settings are missing.")); return }
            for key in ["width", "height"] {
                guard let n = p[key]?.number, n > 0, Int(exactly: n) != nil else { try fail(L("Custom \(key) must be a positive integer.")); return }
            }
            guard let scale = p["scale"]?.number, [1.0, 2.0].contains(scale),
                  let pointer = p["pointerScale"]?.number, pointer.isFinite, pointer > 0 else { try fail(L("Scale must be 1 or 2; pointer scale must be positive.")); return }
        }
        // Match the backend's conservative boundary around its legacy shell commands.
        for key in ["title", "id", "exeName", "wrapper", "dllOverrides", "ps1Script", "gameDir", "saveDir"] {
            var text = key == "id" ? storeID : optionalText(key)
            if key == "gameDir" || key == "saveDir" {
                for prefix in ["$WRAPPER", "$HOME"] where text == prefix || text.hasPrefix(prefix + "/") {
                    text.removeFirst(prefix.count)
                }
            }
            if text.rangeOfCharacter(from: CharacterSet(charactersIn: "\"`$\\\r\n\0")) != nil {
                try fail(L("\(key) contains unsupported shell quoting characters. Use forward slashes; only leading $HOME/ and $WRAPPER/ are supported in directory fields."))
            }
        }
    }
}

public struct LibraryDocument: Codable, Equatable {
    public var games: [GameRecord]
    public var extras: [String: JSONValue]
    public init(games: [GameRecord], extras: [String: JSONValue] = [:]) { self.games = games; self.extras = extras }
    public init(from decoder: Decoder) throws {
        var root = try [String: JSONValue](from: decoder)
        guard root.removeValue(forKey: "schemaVersion") == .number(1) else { throw LibraryError(L("Unsupported library version. Expected schemaVersion 1.")) }
        guard case .array(let rows)? = root.removeValue(forKey: "games") else { throw LibraryError(L("The library must contain a games array.")) }
        games = try rows.map { row in
            guard let object = row.object else { throw LibraryError(L("Each game must be an object.")) }
            return GameRecord(values: object)
        }
        extras = root
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        var root = extras
        root["schemaVersion"] = .number(1)
        root["games"] = .array(games.map { .object($0.values) })
        try root.encode(to: encoder)
    }
    public func validate() throws {
        var aliases = Set<String>()
        for game in games {
            try game.validate()
            guard aliases.insert(game.alias).inserted else { throw LibraryError(L("Duplicate alias: \(game.alias)")) }
        }
    }
}

public enum LibraryRepository {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Game Launcher/games.json")
    }
    public static func load(_ url: URL) throws -> (LibraryDocument, Data) {
        let data = try Data(contentsOf: url)
        return (try JSONDecoder().decode(LibraryDocument.self, from: data), data)
    }
    public static func encode(_ document: LibraryDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }
    @discardableResult
    public static func save(_ document: LibraryDocument, to url: URL, expected: Data) throws -> Data {
        let data = try encode(document)
        let current = try Data(contentsOf: url)
        guard current == expected else {
            throw LibraryError(L("The library changed on disk. Your draft has not been saved. Export a copy to preserve it, then reload before editing again."))
        }
        try current.write(to: url.appendingPathExtension("backup"), options: .atomic)
        try data.write(to: url, options: .atomic)
        return data
    }
}
