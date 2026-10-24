import XCTest
import CoreGraphics
@testable import LauncherCore

final class StandaloneLauncherTests: XCTestCase {
    func testOldConfigurationDefaultsToRDMAndNativeChoiceRoundTrips() throws {
        let legacy = configuration()
        let legacyBytes = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(StandaloneConfiguration.self, from: legacyBytes)
        XCTAssertNil(decoded.nativeDisplay)
        XCTAssertNil(decoded.wineEnvironmentPath)
        var native = legacy; native.nativeDisplay = true
        XCTAssertEqual(try JSONDecoder().decode(StandaloneConfiguration.self, from: JSONEncoder().encode(native)), native)
    }
    func testWineExportCopiesAdaptersButNotTheLiveEnvironment() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        var opts = options()
        opts.configuration.wineEnvironmentPath = "/Users/example/Script's folder/wine_env.sh"
        XCTAssertThrowsError(try fixture.build(options: opts) { _ in XCTFail("Reject old backend") })
        try Data("#lang racket\n;; live-wine-env-v1\n".utf8).write(to: fixture.backend.appendingPathComponent("wine.rkt"))
        for name in ["wine-launch.sh", "wine-cleanup.sh", "blackbars", "runtime_loader", "libRuntimeRosettax87"] {
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: fixture.backend.appendingPathComponent(name))
        }
        try fixture.build(options: opts) { _ in }
        let resources = fixture.destination.appendingPathComponent("Contents/Resources")
        XCTAssertEqual(try StandaloneConfiguration.load(resources: resources).wineEnvironmentPath, opts.configuration.wineEnvironmentPath)
        for name in ["wine-launch.sh", "wine-cleanup.sh", "blackbars", "runtime_loader", "libRuntimeRosettax87"] {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: resources.appendingPathComponent("Backend/" + name).path))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Backend/wine_env.sh").path))
    }
    func testNativeExportRejectsOldBackendBeforePublishing() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        var opts = options(); opts.configuration.nativeDisplay = true
        XCTAssertThrowsError(try fixture.build(options: opts) { _ in XCTFail("Must reject old native backend") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
    }
    func testNativeExportCopiesOwnershipModuleAndSelection() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try Data("#lang racket\n;; native-display-owner-v1\n".utf8).write(to: fixture.backend.appendingPathComponent("display.rkt"))
        try Data("#lang racket\n".utf8).write(to: fixture.backend.appendingPathComponent("native-display.rkt"))
        try Data("#!/bin/sh\n# native-display-owner-v1\n".utf8).write(to: fixture.play)
        var opts = options(); opts.configuration.nativeDisplay = true
        try fixture.build(options: opts) { _ in }
        let resources = fixture.destination.appendingPathComponent("Contents/Resources")
        XCTAssertEqual(try StandaloneConfiguration.load(resources: resources).nativeDisplay, true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Backend/native-display.rkt").path))
    }
    func testNamesAndIdentifiers() throws {
        XCTAssertEqual(LauncherNaming.identifier(username: "Pédro", title: "Game: The Sequel!", alias: "game2"), "org.pedro.gamethesequel")
        XCTAssertEqual(LauncherNaming.identifier(username: "", title: "日本語", alias: "example"), "org.user.example")
        XCTAssertEqual(LauncherNaming.filename(title: "Game: Part/Two", alias: "game"), "Game Part-Two.app")
        XCTAssertEqual(LauncherNaming.filename(title: "...", alias: "fallback"), "fallback.app")
        for bad in ["org.pedro.Game:Two", "org.pedro.two words", "org..game", "org.user.game/escape", "", "single", "org.-bad.game"] {
            XCTAssertThrowsError(try LauncherNaming.validateIdentifier(bad))
        }
        try LauncherNaming.validateIdentifier("org.pedro.game-two")
    }
    func testConfigurationRoundTripAndValidation() throws {
        XCTAssertEqual(LauncherPresentation.allCases, [.progress, .text, .none])
        XCTAssertTrue(LauncherPresentation.progress.showsWindow)
        XCTAssertTrue(LauncherPresentation.text.showsWindow)
        XCTAssertFalse(LauncherPresentation.none.showsWindow)
        for style in LauncherPresentation.allCases {
            var variant = configuration(); variant.presentation = style
            let encoded = try JSONEncoder().encode(variant)
            XCTAssertEqual(try JSONDecoder().decode(StandaloneConfiguration.self, from: encoded), variant)
        }
        let config = configuration()
        let data = try JSONEncoder().encode(config)
        XCTAssertEqual(try JSONDecoder().decode(StandaloneConfiguration.self, from: data), config)
        var bad = config; bad.schemaVersion = 2
        XCTAssertThrowsError(try bad.validate())
        bad = config; bad.alias = "--list"
        XCTAssertThrowsError(try bad.validate())
        bad = config; bad.libraryPath = "relative.json"
        XCTAssertThrowsError(try bad.validate())
        bad = config; bad.racketPath = "racket"
        XCTAssertThrowsError(try bad.validate())
        bad = config; bad.title = "\n"
        XCTAssertThrowsError(try bad.validate())
    }
    func testBuildCopiesRuntimeAndSourcesButReferencesLiveLibrary() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let icon = fixture.root.appendingPathComponent("icon.icns")
        try Data([105, 99, 110, 115, 0, 0, 0, 8]).write(to: icon) // Minimal ICNS container header.
        let options = LauncherExportOptions(configuration: configuration(), identifier: "org.test.example", icon: icon)
        var finalized = false
        try fixture.build(options: options) { app in
            XCTAssertTrue(FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/MacOS/GameRunner").path))
            finalized = true
        }
        XCTAssertTrue(finalized)
        let resources = fixture.destination.appendingPathComponent("Contents/Resources")
        XCTAssertEqual(try StandaloneConfiguration.load(resources: resources), options.configuration)
        XCTAssertEqual(try Data(contentsOf: resources.appendingPathComponent("Backend/play")), try Data(contentsOf: fixture.play))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Backend/runners/test.rkt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Backend/compiled").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Backend/wine_env.sh").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("games.json").path))
        let data = try Data(contentsOf: fixture.destination.appendingPathComponent("Contents/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "org.test.example")
        XCTAssertEqual(plist["CFBundleName"] as? String, "Game: Example")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "GameRunner")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "GameIcon.icns")
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.destination.appendingPathComponent("Contents/MacOS/GameRunner").path))
    }
    func testExistingAppIsNeverOverwritten() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try FileManager.default.createDirectory(at: fixture.destination, withIntermediateDirectories: false)
        let sentinel = fixture.destination.appendingPathComponent("keep.txt")
        try Data("do not change".utf8).write(to: sentinel)
        XCTAssertThrowsError(try fixture.build(options: options()) { _ in XCTFail("Should not sign an existing app") })
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "do not change")
    }
    func testFailedSigningLeavesNoAppOrStagingDirectory() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        XCTAssertThrowsError(try fixture.build(options: options()) { _ in throw LibraryError("Signing failed") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).contains { $0.hasPrefix(".launcher-export-") })
    }
    func testBadIconAndMissingRuntimeFailBeforePublishing() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let icon = fixture.root.appendingPathComponent("bad.icns")
        try Data("not an icon".utf8).write(to: icon)
        var opts = options(); opts.icon = icon
        XCTAssertThrowsError(try fixture.build(options: opts) { _ in XCTFail("Should not sign") })
        try FileManager.default.removeItem(at: fixture.executable)
        XCTAssertThrowsError(try fixture.build(options: options()) { _ in XCTFail("Should not sign") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
    }
    func testWindowCentersNearMenuBarAfterDisplayResize() {
        let native = LauncherWindowPlacement.topLeft(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1600),
            visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1576), windowWidth: 560)
        XCTAssertEqual(native, CGPoint(x: 1000, y: 1572))
        let resized = LauncherWindowPlacement.topLeft(
            screenFrame: CGRect(x: 0, y: 0, width: 2048, height: 1280),
            visibleFrame: CGRect(x: 0, y: 0, width: 2048, height: 1256), windowWidth: 560)
        XCTAssertEqual(resized, CGPoint(x: 744, y: 1252))
    }
    func testWindowCentersOnDisplayWithNegativeOriginAndSideDock() {
        let point = LauncherWindowPlacement.topLeft(
            screenFrame: CGRect(x: -1920, y: -200, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1850, y: -200, width: 1850, height: 1056), windowWidth: 560)
        XCTAssertEqual(point, CGPoint(x: -1240, y: 852))
    }
    func testWindowPlacementClampsToVisibleHorizontalArea() {
        let point = LauncherWindowPlacement.topLeft(
            screenFrame: CGRect(x: 0, y: 0, width: 640, height: 480),
            visibleFrame: CGRect(x: 80, y: 0, width: 560, height: 456), windowWidth: 560)
        XCTAssertEqual(point, CGPoint(x: 80, y: 452))
    }
    private func configuration() -> StandaloneConfiguration {
        StandaloneConfiguration(alias: "example", title: "Game: Example", libraryPath: "/Users/example/Games' library/games.json",
                                racketPath: "", presentation: .progress)
    }
    private func options() -> LauncherExportOptions {
        LauncherExportOptions(configuration: configuration(), identifier: "org.test.example", icon: nil)
    }
    private final class Fixture {
        let root: URL
        var destination: URL { root.appendingPathComponent("Game Example.app") }
        var backend: URL { root.appendingPathComponent("backend") }
        var executable: URL { root.appendingPathComponent("mock-runner") }
        var play: URL { root.appendingPathComponent("play") }
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("launcher-test-" + UUID().uuidString)
            let fm = FileManager.default
            try fm.createDirectory(at: backend.appendingPathComponent("runners"), withIntermediateDirectories: true)
            try fm.createDirectory(at: backend.appendingPathComponent("compiled"), withIntermediateDirectories: true)
            for name in ["main.rkt", "library.rkt", "runners/test.rkt", "compiled/ignored.rkt"] {
                try Data("#lang racket\n".utf8).write(to: backend.appendingPathComponent(name))
            }
            try Data("external".utf8).write(to: backend.appendingPathComponent("wine_env.sh"))
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            try Data("#!/bin/sh\necho mock-play\n".utf8).write(to: play)
        }
        func build(options: LauncherExportOptions, finalize: (URL) throws -> Void) throws {
            try LauncherBundleBuilder.build(at: destination, options: options, executable: executable, backend: backend, play: play, finalize: finalize)
        }
        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}
