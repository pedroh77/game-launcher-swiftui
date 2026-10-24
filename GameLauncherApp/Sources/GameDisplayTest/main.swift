import Foundation
import Dispatch
import Darwin
import LauncherRuntime

// This executable never launches play, sends clicks, or adjusts pointer settings.
// --test runs a short-lived worker plus an independent parent watchdog. The editor
// is not the process changing display modes during this diagnostic.
func report(_ text: String) { print(text); fflush(stdout) }
func fail(_ error: Error) -> Never {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(70)
}
func preview(_ profile: String) throws {
    let session = try NativeDisplayTestSession(profile: profile)
    report(session.summary)
    // Preflight only; releasing the object releases the lock. No mode was set.
}
func worker(_ profile: String) throws -> Never {
    let session = try NativeDisplayTestSession(profile: profile)
    report(session.summary)
    var finished = false
    func restoreAndExit(_ code: Int32) {
        guard !finished else { return }; finished = true
        do {
            try session.restore()
            report("RESTORED: captured desktop mode verified. No pointer settings were changed.")
            exit(code)
        } catch { fail(error) } // Process exit also releases CoreGraphics' temporary mode.
    }
    let signals = [SIGINT, SIGTERM, SIGHUP].map { value -> DispatchSourceSignal in
        signal(value, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: value, queue: .main)
        source.setEventHandler { restoreAndExit(130) }
        source.resume()
        return source
    }
    do { try session.begin() }
    catch {
        let original = error
        do { try session.restore() }
        catch { report("Rollback failed; process-exit fallback will apply: \(error.localizedDescription)") }
        fail(original)
    }
    report("TEST ACTIVE: restoring automatically in 12 seconds. Ctrl+C restores early.")
    DispatchQueue.main.asyncAfter(deadline: .now() + 12) { restoreAndExit(0) }
    withExtendedLifetime(signals) { dispatchMain() }
}
func guardedTest(_ profile: String) throws -> Never {
    try preview(profile)
    report("Save work and stop all games/display tools first. This changes only resolution for 12 seconds.")
    report("A watchdog stops only the test worker if it stalls. Abnormal exit falls back to the permanent Displays setting, not necessarily the captured mode.")
    report("Type TEST and press Return to proceed (anything else cancels):")
    guard readLine() == "TEST" else { report("Cancelled without switching."); exit(0) }
    let child = Process()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    child.arguments = ["--worker", profile]
    child.standardInput = FileHandle.nullDevice
    child.standardOutput = FileHandle.standardOutput; child.standardError = FileHandle.standardError
    let signals = [SIGINT, SIGTERM, SIGHUP].map { value -> DispatchSourceSignal in
        signal(value, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: value, queue: .global())
        source.setEventHandler { if child.isRunning { child.terminate() } }
        source.resume(); return source
    }
    try child.run()
    // Independent of the worker's main queue and display-switch call.
    let timeout = DispatchWorkItem {
        if child.isRunning {
            report("WATCHDOG: asking stalled display test to restore and exit.")
            child.terminate()
        }
    }
    let hardTimeout = DispatchWorkItem {
        if child.isRunning {
            report("WATCHDOG: ending stalled worker; macOS process-lifetime fallback should restore the permanent Displays mode.")
            kill(child.processIdentifier, SIGKILL)
        }
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: timeout)
    DispatchQueue.global().asyncAfter(deadline: .now() + 23, execute: hardTimeout)
    withExtendedLifetime(signals) { child.waitUntilExit() }
    timeout.cancel(); hardTimeout.cancel()
    let code = child.terminationReason == .exit ? child.terminationStatus : 70
    if code == 0 {
        report("Worker exited. Check that your desktop is still correct before enabling native display mode in Settings.")
    } else { report("Test did not complete normally. Keep RDM selected and inspect System Settings → Displays.") }
    exit(code)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, ["--check", "--test", "--worker"].contains(arguments[0]) else {
    report("Usage: GameDisplayTest --check|--test PROFILE\nExample: GameDisplayTest --test 2048x1280")
    exit(2)
}
do {
    switch arguments[0] {
    case "--check": try preview(arguments[1])
    case "--test": try guardedTest(arguments[1])
    default: try worker(arguments[1])
    }
} catch { fail(error) }
