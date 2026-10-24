import XCTest
import Combine
import LauncherCore
@testable import LauncherRuntime

final class NativeLaunchControllerTests: XCTestCase {
    @MainActor
    func testNormalAndCancelledSessionsRestoreAfterCleanupBeforeCompletion() async throws {
        for cancel in [false, true] {
            let fixture = try Fixture(cancel ? """
            trap 'echo CLEANUP-DONE; exit 0' TERM
            echo READY
            while :; do sleep 0.05; done
            """ : "echo CLEANUP-DONE\n")
            defer { fixture.remove() }
            let lease = FakeLease()
            let controller = LaunchController(activateOnFailure: false)
            controller.displayFactory = { _, _ in lease }
            let completed = expectation(description: "Display restored after cleanup")
            var requestedCancel = false
            let observation = controller.$output.sink { output in
                if cancel && output.contains("READY") && !requestedCancel {
                    requestedCancel = true; controller.stop(); controller.stop()
                    XCTAssertEqual(lease.events, ["begin"])
                }
            }
            defer { observation.cancel(); controller.onCompletion = nil; controller.stop() }
            lease.beforeRestore = { XCTAssertTrue(controller.output.contains("CLEANUP-DONE")) }
            controller.onCompletion = { code, stopped in
                XCTAssertEqual(code, 0); XCTAssertEqual(stopped, cancel)
                XCTAssertEqual(lease.events, ["begin", "restore"])
                XCTAssertTrue(controller.output.contains("OWNER:2048,1280,1"))
                XCTAssertFalse(controller.isRunning)
                completed.fulfill()
            }
            try fixture.start(controller)
            await fulfillment(of: [completed], timeout: 5)
        }
    }
    @MainActor
    func testRestoreFailureKeepsSessionOpenUntilRetry() async throws {
        let fixture = try Fixture("echo CLEANUP-DONE\n")
        defer { fixture.remove() }
        let lease = FakeLease(); lease.failRestoreOnce = true
        let controller = LaunchController(activateOnFailure: false)
        controller.displayFactory = { _, _ in lease }
        let failed = expectation(description: "Restore failure visible")
        let completed = expectation(description: "Retry finished")
        let observation = controller.$needsDisplayRestore.sink { value in if value { failed.fulfill() } }
        defer { observation.cancel(); controller.onCompletion = nil; controller.stop() }
        controller.onCompletion = { _, _ in
            XCTAssertEqual(lease.events, ["begin", "restore", "restore"])
            completed.fulfill()
        }
        try fixture.start(controller)
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertTrue(controller.isRunning)
        XCTAssertTrue(controller.needsDisplayRestore)
        controller.retryDisplayRestoration()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertFalse(controller.isRunning)
        XCTAssertFalse(controller.needsDisplayRestore)
    }
    @MainActor
    func testBeginFailureRollsBackWithoutLaunchingChild() throws {
        let fixture = try Fixture("echo SHOULD-NOT-RUN\n")
        defer { fixture.remove() }
        let lease = FakeLease(); lease.failBegin = true
        let controller = LaunchController(activateOnFailure: false)
        controller.displayFactory = { _, _ in lease }
        XCTAssertThrowsError(try fixture.start(controller))
        XCTAssertEqual(lease.events, ["begin", "abort"])
        XCTAssertFalse(controller.isRunning)
        XCTAssertFalse(controller.output.contains("SHOULD-NOT-RUN"))
    }
    @MainActor
    func testInfoDoesNotAcquireDisplayOrPassOwnershipMarker() async throws {
        let fixture = try Fixture("exit 0\n")
        defer { fixture.remove() }
        let controller = LaunchController(activateOnFailure: false)
        controller.displayFactory = { _, _ in XCTFail("Info must never acquire a display"); return FakeLease() }
        let completed = expectation(description: "Read-only check")
        controller.onCompletion = { _, _ in
            XCTAssertTrue(controller.output.contains("OWNER:unset"))
            completed.fulfill()
        }
        defer { controller.onCompletion = nil; controller.stop() }
        try fixture.start(controller, info: true)
        await fulfillment(of: [completed], timeout: 5)
    }
    @MainActor
    func testOldBackendRejectedBeforeAcquiringDisplay() throws {
        let fixture = try Fixture("exit 0\n")
        defer { fixture.remove() }
        try Data("old backend".utf8).write(to: fixture.root.appendingPathComponent("display.rkt"))
        let controller = LaunchController(activateOnFailure: false)
        controller.displayFactory = { _, _ in XCTFail("Must reject old backend first"); return FakeLease() }
        XCTAssertThrowsError(try fixture.start(controller))
    }
    private final class FakeLease: DisplayLease {
        let backendValue = "2048,1280,1"
        let summary = "Mock native display"
        var events: [String] = []
        var failBegin = false
        var failRestoreOnce = false
        var beforeRestore: (() -> Void)?
        func begin() throws {
            events.append("begin")
            if failBegin { throw LibraryError("Mock start failure") }
        }
        func restore() throws {
            beforeRestore?(); events.append("restore")
            if failRestoreOnce { failRestoreOnce = false; throw LibraryError("Mock restore failure") }
        }
        func abort() throws { events.append("abort") }
    }
    private final class Fixture {
        let root: URL
        var script: URL { root.appendingPathComponent("mock play.sh") }
        init(_ body: String) throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("native-launch-test-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            try Data(";; native-display-owner-v1\n".utf8).write(to: root.appendingPathComponent("display.rkt"))
            try ("#!/bin/sh\n# native-display-owner-v1\nprintf 'OWNER:%s\\n' \"${GAME_LAUNCHER_NATIVE_DISPLAY:-unset}\"\n" + body)
                .write(to: script, atomically: true, encoding: .utf8)
        }
        @MainActor
        func start(_ controller: LaunchController, info: Bool = false) throws {
            try controller.start(play: script, script: script, library: script, racket: "", alias: "mock", title: "Native Mock", infoOnly: info, nativeDisplay: true)
        }
        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}
