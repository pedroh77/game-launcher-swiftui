import XCTest
import LauncherCore
@testable import LauncherRuntime

final class NativeDisplaySessionTests: XCTestCase {
    private let desktop = DisplayModeDescription(id: 12, width: 1440, height: 900, pixelWidth: 2880, pixelHeight: 1800, refreshRate: 60)
    private let target = DisplayModeDescription(id: 17, width: 2048, height: 1280, pixelWidth: 2048, pixelHeight: 1280, refreshRate: 60)
    private let previous = DisplayModeDescription(id: 7, width: 1280, height: 800, pixelWidth: 2560, pixelHeight: 1600, refreshRate: 60)
    private let spec = DisplayModeSpec(width: 2048, height: 1280, scale: 1)

    func testSelectionDistinguishesLogicalSizeAndFramebuffer() throws {
        let wrongScale = DisplayModeDescription(id: 99, width: 2048, height: 1280, pixelWidth: 4096, pixelHeight: 2560, refreshRate: 60)
        XCTAssertFalse(wrongScale.matches(spec))
        XCTAssertEqual(try DisplayModeDescription.select(spec, modes: [wrongScale, target], current: desktop), target)
        XCTAssertThrowsError(try DisplayModeDescription.select(spec, modes: [wrongScale], current: desktop))
    }
    func testSelectionPrefersCurrentRefreshRateNotLargestValue() throws {
        let fast = DisplayModeDescription(id: 3, width: 2048, height: 1280, pixelWidth: 2048, pixelHeight: 1280, refreshRate: 120)
        XCTAssertEqual(try DisplayModeDescription.select(spec, modes: [fast, target], current: desktop), target)
    }
    func testPreflightRequiresRestoreBeforeAnySwitch() {
        let driver = FakeDriver(current: previous, modes: [previous, target])
        XCTAssertThrowsError(try NativeDisplaySession(spec: spec, driver: driver))
        XCTAssertTrue(driver.changes.isEmpty)
    }
    func testMissingCapturedDesktopRejectsBeforeSwitch() {
        let driver = FakeDriver(current: previous, modes: [target, desktop])
        XCTAssertThrowsError(try NativeDisplaySession(spec: spec, driver: driver, restorePrevious: true))
        XCTAssertTrue(driver.changes.isEmpty)
    }
    func testGameUsesFixedRestoreAndRestoresOnlyOnce() throws {
        let driver = FakeDriver(current: previous, modes: [previous, target, desktop])
        let session = try NativeDisplaySession(spec: spec, driver: driver)
        XCTAssertTrue(driver.changes.isEmpty)
        XCTAssertEqual(session.backendValue, "2048,1280,1")
        try session.begin(); try session.restore(); try session.restore()
        XCTAssertEqual(driver.changes, [target, desktop])
    }
    func testDiagnosticAndLaunchAbortRestoreCapturedDesktop() throws {
        for diagnostic in [false, true] {
            let driver = FakeDriver(current: previous, modes: [previous, target, desktop])
            let session = try NativeDisplaySession(spec: spec, driver: driver, restorePrevious: diagnostic)
            try session.begin()
            if diagnostic { try session.restore() } else { try session.abort() }
            XCTAssertEqual(driver.changes, [target, previous])
        }
    }
    func testFailedSwitchStillRollsBackPotentialPartialChange() throws {
        let driver = FakeDriver(current: previous, modes: [previous, target, desktop])
        let session = try NativeDisplaySession(spec: spec, driver: driver)
        driver.failNextSet = true
        XCTAssertThrowsError(try session.begin())
        try session.abort()
        XCTAssertEqual(driver.changes, [target, previous])
    }
    func testFailedRestoreRetainsTargetForRetry() throws {
        let driver = FakeDriver(current: previous, modes: [previous, target, desktop])
        let session = try NativeDisplaySession(spec: spec, driver: driver)
        try session.begin(); driver.failNextSet = true
        XCTAssertThrowsError(try session.restore())
        try session.restore(); try session.restore()
        XCTAssertEqual(driver.changes, [target, desktop, desktop])
    }
    func testChangedDesktopAfterPreflightAbortsWithoutSwitch() throws {
        let driver = FakeDriver(current: desktop, modes: [previous, target, desktop])
        let session = try NativeDisplaySession(spec: spec, driver: driver)
        driver.active = previous
        XCTAssertThrowsError(try session.begin())
        try session.abort()
        XCTAssertTrue(driver.changes.isEmpty)
    }
    func testOffAnd1080pSkipHaveNoSwitches() throws {
        let off = try NativeDisplaySession(spec: nil, driver: nil)
        try off.begin(); try off.restore()
        XCTAssertEqual(off.backendValue, "skip")
        let hd = DisplayModeDescription(id: 50, width: 1920, height: 1080, pixelWidth: 1920, pixelHeight: 1080, refreshRate: 60)
        let driver = FakeDriver(current: hd, modes: [])
        let skip = try NativeDisplaySession(spec: spec, driver: driver)
        try skip.begin(); try skip.restore()
        XCTAssertEqual(skip.backendValue, "skip")
        XCTAssertTrue(driver.changes.isEmpty)
    }
    func testProfilesAndCustomScaleMatchBackendContract() throws {
        var game = GameRecord.new(alias: "test")
        for (name, expected) in DisplayModeSpec.presets {
            game.displayMode = name
            XCTAssertEqual(try DisplayModeSpec.forGame(game), expected)
        }
        game.displayMode = "off"
        XCTAssertNil(try DisplayModeSpec.forGame(game))
        game.displayMode = "custom"
        game.setCustomNumber("width", 1024); game.setCustomNumber("height", 640)
        game.setCustomNumber("scale", 2)
        XCTAssertEqual(try DisplayModeSpec.forGame(game)?.backendValue, "1024,640,2")
    }

    private final class FakeDriver: DisplayDriver {
        var active: DisplayModeDescription
        let available: [DisplayModeDescription]
        var changes: [DisplayModeDescription] = []
        var failNextSet = false
        init(current: DisplayModeDescription, modes: [DisplayModeDescription]) {
            active = current; available = modes
        }
        func current() throws -> DisplayModeDescription { active }
        func modes() throws -> [DisplayModeDescription] { available }
        func set(_ mode: DisplayModeDescription) throws {
            changes.append(mode); active = mode
            if failNextSet { failNextSet = false; throw LibraryError("Mock switch/verification failure") }
        }
    }
}
