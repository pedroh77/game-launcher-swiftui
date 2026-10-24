import XCTest
@testable import LauncherCore

final class LibraryTests: XCTestCase {
    func testSeedDecodesAndRoundTripsAll118Games() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Resources/games.seed.json")
        let (doc, _) = try LibraryRepository.load(url)
        XCTAssertEqual(doc.games.count, 118)
        let result = try JSONDecoder().decode(LibraryDocument.self, from: LibraryRepository.encode(doc))
        XCTAssertEqual(doc, result)
        XCTAssertEqual(doc.games.first { $0.alias == "afterimage" }?.storeID, "1701520")
        XCTAssertEqual(doc.games.first { $0.alias == "rotn" }?.displayMode, "1680x1050")
        // Do not silently 'fix' a user's imported launch method.
        XCTAssertEqual(doc.games.first { $0.alias == "thefallepic" }?.runner, "direct-wine")
    }
    func testUnknownMetadataSurvivesEditing() throws {
        var game = GameRecord.new(alias: "sample")
        game.values["future"] = .object(["enabled": .bool(true), "list": .array([.number(3), .null])])
        var doc = LibraryDocument(games: [game], extras: ["futureRoot": .string("keep")])
        doc.games[0].title = "Changed title"
        let result = try JSONDecoder().decode(LibraryDocument.self, from: LibraryRepository.encode(doc))
        XCTAssertEqual(result, doc)
    }
    func testDirectNativeDoesNotInheritWineWrapper() throws {
        var game = GameRecord.new(alias: "native")
        game.runner = "direct-mac"
        XCTAssertEqual(game.platform, "direct")
        XCTAssertFalse(game.usesWine)
        XCTAssertEqual(game.values["wrapper"], .null)
        game.runner = "direct-wine"
        XCTAssertTrue(game.usesWine)
        XCTAssertEqual(game.optionalText("wrapper"), "Steam_SK.app")
        try game.validate()
    }
    func testDuplicateAliasesAndMalformedTypesFail() throws {
        let game = GameRecord.new(alias: "sample")
        XCTAssertThrowsError(try LibraryDocument(games: [game, game]).validate())
        var bad = game
        bad.alias = "two words"
        XCTAssertThrowsError(try bad.validate())
        bad = game; bad.values["blackbars"] = .string("true")
        XCTAssertThrowsError(try bad.validate())
        bad = game; bad.values["focusDelay"] = .number(-1)
        XCTAssertThrowsError(try bad.validate())
        bad = game; bad.values["renderer"] = .number(7)
        XCTAssertThrowsError(try bad.validate())
        bad = game; bad.platform = "direct-wine" // UI label, not a canonical backend platform.
        XCTAssertThrowsError(try bad.validate())
        XCTAssertThrowsError(try JSONDecoder().decode(LibraryDocument.self, from: Data("{\"schemaVersion\":2,\"games\":[]}".utf8)))
    }
    func testShellQuotingAndPlaceholders() throws {
        var game = GameRecord.new(alias: "safe")
        for path in ["$HOME/Games", "$WRAPPER/SharedSupport/prefix", "/Games/Kathy’s Game"] {
            game.setOptionalText("gameDir", path)
            XCTAssertNoThrow(try game.validate())
        }
        for path in ["$(touch /tmp/no)", "bad`command`", "bad\"quote", "C:\\Games"] {
            game.setOptionalText("gameDir", path)
            XCTAssertThrowsError(try game.validate())
        }
        game.setOptionalText("gameDir", "")
        game.storeID = "123; echo bad"
        XCTAssertThrowsError(try game.validate())
    }
    func test2048DisplayProfileRoundTripsWithoutChangingOtherSettings() throws {
        let original = GameRecord.new(alias: "display-test")
        XCTAssertEqual(original.displayMode, "2560x1600")
        var game = original
        game.displayMode = "2048x1280"
        // The displayed label comes from the active catalog, so compare it against the same
        // lookup the UI performs rather than a hardcoded English literal, which would fail on
        // any machine whose system language is Brazilian Portuguese. Both catalogs are asserted
        // explicitly so the profile keeps its intended wording in either language.
        XCTAssertEqual(L10n.render("2048 × 1280 · 1× / pointer 2×", language: "en"),
                       "2048 × 1280 · 1× / pointer 2×")
        XCTAssertEqual(L10n.render("2048 × 1280 · 1× / pointer 2×", language: "pt-BR"),
                       "2048 × 1280 · 1× / ponteiro 2×")
        XCTAssertEqual(GameRecord.displays.first { $0.0 == game.displayMode }?.1,
                       L10n.lookup("2048 × 1280 · 1× / pointer 2×"))
        var expected = original.values
        expected["displayMode"] = .string("2048x1280")
        XCTAssertEqual(game.values, expected)
        XCTAssertNil(game.values["customDisplay"])
        let document = LibraryDocument(games: [game])
        let decoded = try JSONDecoder().decode(LibraryDocument.self,
                                               from: LibraryRepository.encode(document))
        XCTAssertEqual(decoded, document)
    }
    func testCustomDisplayValidation() throws {
        var game = GameRecord.new(alias: "custom")
        game.displayMode = "custom"
        XCTAssertThrowsError(try game.validate())
        game.setCustomNumber("width", 1680)
        XCTAssertNoThrow(try game.validate())
        game.setCustomNumber("height", -1)
        XCTAssertThrowsError(try game.validate())
    }
    func testBackupAndExternalChangeDetection() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("games.json")
        var doc = LibraryDocument(games: [GameRecord.new(alias: "sample")])
        let original = try LibraryRepository.encode(doc)
        try original.write(to: url)
        doc.games[0].title = "Edited"
        let saved = try LibraryRepository.save(doc, to: url, expected: original)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathExtension("backup")), original)
        XCTAssertEqual(try LibraryRepository.load(url).0, doc)
        let external = Data("external changes".utf8)
        try external.write(to: url)
        XCTAssertThrowsError(try LibraryRepository.save(doc, to: url, expected: saved))
        XCTAssertEqual(try Data(contentsOf: url), external)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathExtension("backup")), original)
    }
}
