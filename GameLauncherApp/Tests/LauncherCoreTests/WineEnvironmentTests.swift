import XCTest
@testable import LauncherCore

final class WineEnvironmentTests: XCTestCase {
    func testDefaultsAndAbsolutePathValidation() throws {
        XCTAssertEqual(try WineEnvironment.resolvedPath(nil), WineEnvironment.defaultPath)
        XCTAssertEqual(try WineEnvironment.resolvedPath(""), WineEnvironment.defaultPath)
        let path = "/Users/example/Script's folder/wine_env.sh"
        XCTAssertEqual(try WineEnvironment.resolvedPath(path), path)
        for invalid in ["relative.sh", "~/bin/wine_env.sh", "/tmp/a\n.sh", "/tmp/a\0.sh"] {
            XCTAssertThrowsError(try WineEnvironment.resolvedPath(invalid))
        }
    }
    func testReadableScriptWithoutExecutingOrCopyingIt() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let script = folder.appendingPathComponent("live script.sh")
        let source = "# This is data for the test; never execute it.\n"
        try source.write(to: script, atomically: true, encoding: .utf8)
        XCTAssertEqual(try WineEnvironment.readableURL(script.path), script)
        XCTAssertEqual(try String(contentsOf: script, encoding: .utf8), source)
        let link = folder.appendingPathComponent("linked.sh")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: script)
        XCTAssertEqual(try WineEnvironment.readableURL(link.path), link)
        XCTAssertThrowsError(try WineEnvironment.readableURL(folder.path))
        XCTAssertThrowsError(try WineEnvironment.readableURL(folder.appendingPathComponent("missing").path))
    }
}
