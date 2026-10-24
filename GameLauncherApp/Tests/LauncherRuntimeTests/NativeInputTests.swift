import XCTest
import CoreGraphics
import Combine
import LauncherCore
@testable import LauncherRuntime

@MainActor
private final class MockInputDriver: NativeInputDriver {
    var actions: [String] = []
    var restoreFails = false
    func preflight() throws { actions.append("preflight") }
    func click(_ point: CGPoint) throws { actions.append("click") }
    func hide() throws { actions.append("hide") }
    func restore() throws {
        actions.append("restore")
        if restoreFails { throw LibraryError("mock restore failure") }
    }
}

final class NativeInputTests: XCTestCase {
    @MainActor private func send(_ owner: NativeInputSession, sequence: Int, action: String,
                                 age: Double = 0, token: String? = nil, coords: String? = nil) throws {
        let request = NativeInputSession.Request(token: token ?? owner.token, sequence: sequence, action: action,
            coords: action == "hide" ? nil : (coords ?? "12,34"), createdAt: Date().timeIntervalSince1970 - age)
        try JSONEncoder().encode(request).write(to: owner.directory.appendingPathComponent("request.json"), options: .atomic)
        owner.poll()
    }
    @MainActor func testExactSequenceAcknowledgedAndDuplicateDoesNotClickAgain() throws {
        let driver = MockInputDriver()
        let owner = try NativeInputSession(coords: "12,34", driver: driver, report: { _ in }, acquireLock: false, startTimer: false)
        defer { try? owner.close() }
        for (index, action) in ["click", "click", "hide", "click", "hide"].enumerated() {
            try send(owner, sequence: index + 1, action: action)
            owner.poll() // same file must not be replayed
            let response = try JSONDecoder().decode(NativeInputSession.Response.self,
                from: Data(contentsOf: owner.directory.appendingPathComponent("response.json")))
            XCTAssertEqual(response.sequence, index + 1); XCTAssertTrue(response.ok)
        }
        XCTAssertEqual(driver.actions, ["preflight", "click", "click", "hide", "click", "hide"])
        try owner.close(); try owner.close()
        XCTAssertEqual(driver.actions.last, "restore")
        XCTAssertEqual(driver.actions.filter { $0 == "restore" }.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: owner.directory.path))
    }
    @MainActor func testInvalidAndStaleRequestsNeverPostInput() throws {
        for variant in ["token", "sequence", "coords", "stale", "future", "action"] {
            let driver = MockInputDriver()
            let owner = try NativeInputSession(coords: "12,34", driver: driver, report: { _ in }, acquireLock: false, startTimer: false)
            defer { try? owner.close() }
            try send(owner, sequence: variant == "sequence" ? 2 : 1, action: variant == "action" ? "hide" : "click",
                     age: variant == "stale" ? 4 : (variant == "future" ? -10 : 0),
                     token: variant == "token" ? "wrong" : nil, coords: variant == "coords" ? "1,2" : nil)
            XCTAssertEqual(driver.actions, ["preflight", "restore"], variant)
            XCTAssertTrue(FileManager.default.fileExists(atPath: owner.directory.appendingPathComponent("cancelled").path))
            try send(owner, sequence: 1, action: "click")
            XCTAssertFalse(driver.actions.contains("click"), variant)
        }
    }
    @MainActor func testCancellationAndFailedRestoreAreRetryableWithoutLateActions() throws {
        let driver = MockInputDriver()
        let owner = try NativeInputSession(coords: "12,34", driver: driver, report: { _ in }, acquireLock: false, startTimer: false)
        defer { driver.restoreFails = false; try? owner.close() }
        try send(owner, sequence: 1, action: "click")
        driver.restoreFails = true
        XCTAssertThrowsError(try owner.close())
        XCTAssertTrue(FileManager.default.fileExists(atPath: owner.directory.path))
        try send(owner, sequence: 2, action: "click")
        XCTAssertEqual(driver.actions.filter { $0 == "click" }.count, 1)
        driver.restoreFails = false
        try owner.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: owner.directory.path))
    }
    @MainActor func testInheritedNativeInputOwnerIsNotPassedThrough() {
        let url = URL(fileURLWithPath: "/tmp/example")
        XCTAssertNil(LaunchController.environment(library: url, script: url, racket: "")[NativeInputSession.environmentKey])
    }
    @MainActor func testControllerCancelsInputBeforeBackendCleanupCompletes() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["focus.rkt", "native-input.rkt"] {
            try "native-input-owner-v1".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let script = folder.appendingPathComponent("mock.sh")
        try """
        trap 'sleep 0.1; echo CLEANUP-FINISHED; exit 0' TERM
        echo INPUT-READY
        while :; do sleep 0.1; done
        """.write(to: script, atomically: true, encoding: .utf8)
        let driver = MockInputDriver()
        let owner = try NativeInputSession(coords: "12,34", driver: driver, report: { _ in }, acquireLock: false, startTimer: false)
        defer { try? owner.close() }
        let controller = LaunchController(activateOnFailure: false)
        controller.inputFactory = { _, _, _ in owner }
        defer { controller.stop(); controller.onCompletion = nil }
        let done = expectation(description: "backend cleanup finishes after input cancellation")
        let observation = controller.$output.sink { text in
            if text.contains("INPUT-READY"), !controller.isStopping {
                controller.stop()
                XCTAssertFalse(controller.hasNativeInput)
                XCTAssertTrue(controller.isRunning)
                XCTAssertEqual(driver.actions.last, "restore")
            }
        }
        defer { observation.cancel() }
        controller.onCompletion = { code, stopped in
            XCTAssertEqual(code, 0); XCTAssertTrue(stopped)
            XCTAssertTrue(controller.output.contains("CLEANUP-FINISHED")); done.fulfill()
        }
        try controller.start(play: script, script: script, library: script, racket: "", alias: "mock", title: "Test", infoOnly: false, nativeInput: true)
        await fulfillment(of: [done], timeout: 5)
    }
}
