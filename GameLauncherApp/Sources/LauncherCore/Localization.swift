import Foundation

// Explicit localization works in SwiftUI, AppKit and the exported runner alike.
// Interpolated values are arguments, never lookup keys or persisted translations.
public struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public var key: String
    public var arguments: [String]
    public init(stringLiteral value: String) {
        key = value.replacingOccurrences(of: "%", with: "%%"); arguments = []
    }
    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key; arguments = stringInterpolation.arguments
    }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity); arguments.reserveCapacity(interpolationCount)
        }
        public mutating func appendLiteral(_ literal: String) {
            key += literal.replacingOccurrences(of: "%", with: "%%")
        }
        public mutating func appendInterpolation<T>(_ value: T) {
            key += "%@"; arguments.append(String(describing: value))
        }
    }
}

public func L(_ message: LocalizedMessage) -> String { L10n.render(message) }

public enum L10n {
    public static func selectedLanguage(preferences: [String]) -> String {
        for preference in preferences {
            let tag = preference.replacingOccurrences(of: "_", with: "-").lowercased()
            if tag == "pt" || tag.hasPrefix("pt-") { return "pt-BR" }
            if tag == "en" || tag.hasPrefix("en-") { return "en" }
        }
        return "en"
    }
    public static let language = selectedLanguage(preferences: Locale.preferredLanguages)
    public static var locale: Locale { Locale(identifier: language) }
    private static func bundle(_ language: String) -> Bundle {
        let root = Bundle.module
        let path = root.path(forResource: language, ofType: "lproj")
            ?? root.path(forResource: language.lowercased(), ofType: "lproj")
        return path.flatMap(Bundle.init(path:)) ?? root
    }
    public static func render(_ message: LocalizedMessage, language: String = L10n.language) -> String {
        let format = bundle(language).localizedString(forKey: message.key, value: message.key, table: "Localizable")
        return String(format: format, locale: Locale(identifier: language), arguments: message.arguments.map { $0 as CVarArg })
    }
    public static func lookup(_ key: String) -> String { render(LocalizedMessage(stringLiteral: key)) }
    public static func copyResources(to directory: URL) throws {
        let source = Bundle.module.bundleURL
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(source.lastPathComponent))
    }
}
