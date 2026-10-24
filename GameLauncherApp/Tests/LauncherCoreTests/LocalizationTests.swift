import XCTest
@testable import LauncherCore

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageAndEnglishFallback() {
        XCTAssertEqual(L10n.selectedLanguage(preferences: ["pt-BR", "en"]), "pt-BR")
        XCTAssertEqual(L10n.selectedLanguage(preferences: ["en-BR", "pt-BR"]), "en")
        XCTAssertEqual(L10n.selectedLanguage(preferences: ["de", "pt_BR"]), "pt-BR")
        XCTAssertEqual(L10n.selectedLanguage(preferences: ["ja"]), "en")
    }
    func testBothCatalogsAndSafeInterpolation() {
        XCTAssertEqual(L10n.render("Ready", language: "pt-BR"), "Pronto")
        XCTAssertEqual(L10n.render("Ready", language: "en"), "Ready")
        XCTAssertEqual(L10n.render("No window", language: "pt-BR"), "Sem janela")
        XCTAssertEqual(L10n.render("No window", language: "en"), "No window")
        let game = "Jogo %@ 100%"
        XCTAssertEqual(L10n.render("Running: \(game)", language: "pt-BR"), "Em execução: Jogo %@ 100%")
        XCTAssertEqual(L10n.render("Unknown literal %@", language: "pt-BR"), "Unknown literal %@")
        XCTAssertEqual(L10n.render("\(1) games", language: "en"), "1 games")
    }
    func testLocalizationResourceCopyForStandaloneApps() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        try L10n.copyResources(to: folder)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let bundle = try XCTUnwrap(files.first.flatMap(Bundle.init(url:)))
        let path = try XCTUnwrap(bundle.path(forResource: "pt-BR", ofType: "lproj") ?? bundle.path(forResource: "pt-br", ofType: "lproj"))
        let portuguese = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(portuguese.localizedString(forKey: "Ready", value: nil, table: "Localizable"), "Pronto")
    }
    func testOlderExportsDefaultToLegacyInput() throws {
        let json = #"{"schemaVersion":1,"alias":"game","title":"Game","libraryPath":"/tmp/games.json","racketPath":"","presentation":"text"}"#
        let config = try JSONDecoder().decode(StandaloneConfiguration.self, from: Data(json.utf8))
        XCTAssertNil(config.nativeInput)
        var updated = config; updated.nativeInput = true
        XCTAssertEqual(try JSONDecoder().decode(StandaloneConfiguration.self, from: JSONEncoder().encode(updated)), updated)
    }
}
