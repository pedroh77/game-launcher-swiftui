import XCTest
import Combine
import LauncherCore
@testable import LauncherRuntime

final class LaunchControllerTests: XCTestCase {
    @MainActor
    func testWineEnvironmentPathIsPassedLiterally() throws {
        let url = URL(fileURLWithPath: "/tmp/example")
        let selected = "/tmp/A's script $name.sh"
        let env = LaunchController.environment(library: url, script: url, racket: "", wineEnvironmentPath: selected)
        XCTAssertEqual(env[WineEnvironment.environmentKey], selected)
        XCTAssertEqual(LaunchController.environment(library: url, script: url, racket: "")[WineEnvironment.environmentKey], WineEnvironment.defaultPath)
    }

    @MainActor
    func testNormalExitDrainsOutputAndPreservesArguments() async throws {
        let script = try mockScript("""
        printf 'ALIAS:%s\\n' "$1"
        printf 'LIBRARY:%s\\n' "$GAME_LAUNCHER_LIBRARY"
        printf 'FINAL OUTPUT\\n'
        exit 7
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = LaunchController(activateOnFailure: false)
        defer { controller.stop(); controller.onCompletion = nil }
        let completed = expectation(description: "Mock script completed")
        controller.onCompletion = { code, stopped in
            XCTAssertEqual(code, 7); XCTAssertFalse(stopped)
            XCTAssertTrue(controller.output.contains("ALIAS:example-game"))
            XCTAssertTrue(controller.output.contains("LIBRARY:/tmp/Library's path/games.json"))
            XCTAssertTrue(controller.output.contains("FINAL OUTPUT"))
            XCTAssertFalse(controller.isRunning)
            completed.fulfill()
        }
        try controller.start(play: script, script: script, library: URL(fileURLWithPath: "/tmp/Library's path/games.json"),
                             racket: "", alias: "example-game", title: "Test", infoOnly: false)
        await fulfillment(of: [completed], timeout: 5)
        controller.onCompletion = nil
    }
    @MainActor
    func testShortOutputArrivesBeforeProcessExit() async throws {
        let script = try mockScript("""
        trap 'exit 0' TERM
        printf 'STREAMING-READY\\n'
        while [ ! -f "$GAME_LAUNCHER_LIBRARY" ]; do sleep 0.05; done
        printf 'STREAMING-FINISHED\\n'
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let release = script.deletingLastPathComponent().appendingPathComponent("release")
        let controller = LaunchController(activateOnFailure: false)
        defer { controller.stop(); controller.onCompletion = nil }
        let ready = expectation(description: "Short status line delivered before child exits")
        let completed = expectation(description: "Mock script completed after release")
        var sawReady = false
        let observation = controller.$output.sink { output in
            if output.contains("STREAMING-READY"), !sawReady {
                sawReady = true
                XCTAssertTrue(controller.isRunning)
                ready.fulfill()
            }
        }
        defer { observation.cancel() }
        controller.onCompletion = { code, stopped in
            XCTAssertEqual(code, 0); XCTAssertFalse(stopped)
            XCTAssertTrue(controller.output.contains("STREAMING-FINISHED"))
            completed.fulfill()
        }
        try controller.start(play: script, script: script, library: release, racket: "", alias: "mock", title: "Streaming", infoOnly: false)
        await fulfillment(of: [ready], timeout: 2)
        XCTAssertTrue(sawReady, "Output must arrive while the pipe is still open. Captured: \(controller.output)")
        // Always release the fixture after the readiness check, even if it failed.
        // This lets a regressed bulk reader reach EOF instead of leaking a child.
        try Data().write(to: release)
        await fulfillment(of: [completed], timeout: 5)
    }
    @MainActor
    func testCancelSendsTermOnceAndWaitsForCleanupOutput() async throws {
        let script = try mockScript("""
        trap 'echo TERM-RECEIVED; sleep 0.1; echo CLEANUP-FINISHED; exit 0' TERM
        echo READY-TO-CANCEL
        while :; do sleep 0.1; done
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = LaunchController(activateOnFailure: false)
        defer { controller.stop(); controller.onCompletion = nil }
        let completed = expectation(description: "Mock cleanup completed")
        var observation: AnyCancellable?
        observation = controller.$output.sink { output in
            if output.contains("READY-TO-CANCEL"), !controller.isStopping {
                controller.stop()
                controller.stop() // Must not send a second SIGTERM during cleanup.
                XCTAssertTrue(controller.isRunning)
                XCTAssertTrue(controller.isStopping)
            }
        }
        controller.onCompletion = { code, stopped in
            XCTAssertEqual(code, 0); XCTAssertTrue(stopped)
            XCTAssertTrue(controller.output.contains("CLEANUP-FINISHED"))
            XCTAssertEqual(controller.output.components(separatedBy: "TERM-RECEIVED").count - 1, 1)
            XCTAssertFalse(controller.isRunning)
            completed.fulfill()
        }
        try controller.start(play: script, script: script, library: script, racket: "", alias: "mock", title: "Mock", infoOnly: false)
        await fulfillment(of: [completed], timeout: 5)
        observation?.cancel(); controller.onCompletion = nil
    }
    @MainActor
    func testInfoFlagIsPassedWithoutShellInterpolation() async throws {
        let script = try mockScript("printf '%s|%s\\n' \"$1\" \"$2\"\n")
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = LaunchController(activateOnFailure: false)
        defer { controller.stop(); controller.onCompletion = nil }
        let completed = expectation(description: "Info arguments delivered")
        controller.onCompletion = { code, stopped in
            XCTAssertEqual(code, 0); XCTAssertFalse(stopped)
            XCTAssertTrue(controller.output.contains("--info|mock"))
            completed.fulfill()
        }
        try controller.start(play: script, script: script, library: script, racket: "", alias: "mock", title: "Mock", infoOnly: true)
        await fulfillment(of: [completed], timeout: 5)
        controller.onCompletion = nil
    }
    private func mockScript(_ text: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("runner-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let script = folder.appendingPathComponent("mock script.sh")
        try ("#!/bin/sh\n" + text).write(to: script, atomically: true, encoding: .utf8)
        return script
    }
}
