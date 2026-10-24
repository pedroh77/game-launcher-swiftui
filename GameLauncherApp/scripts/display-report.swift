// Read-only diagnostic. Run on your Mac:
// xcrun swift GameLauncherApp/scripts/display-report.swift > display-report.json
// Does not switch modes, change preferences, capture the screen, or launch games.
import Foundation
import CoreGraphics
import Darwin

struct ModeReport: Encodable {
    let id: UInt32
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let scaleX: Double
    let scaleY: Double
    let refreshRate: Double

    init(_ mode: CGDisplayMode) {
        id = UInt32(truncatingIfNeeded: mode.ioDisplayModeID)
        width = mode.width; height = mode.height
        pixelWidth = mode.pixelWidth; pixelHeight = mode.pixelHeight
        scaleX = Double(mode.pixelWidth) / Double(max(mode.width, 1))
        scaleY = Double(mode.pixelHeight) / Double(max(mode.height, 1))
        refreshRate = mode.refreshRate
    }
}
struct DisplayReport: Encodable {
    let id: UInt32
    let builtIn: Bool
    let main: Bool
    let mirrorsDisplay: UInt32
    let current: ModeReport?
    let modes: [ModeReport]
}
struct Report: Encodable {
    let formatVersion = 1
    let note = "Read-only public CoreGraphics mode enumeration. pixelWidth/pixelHeight describe the mode framebuffer, not necessarily physical panel resolution. A listed mode still needs a safe switch/restore test. No display serial numbers or screen contents are collected."
    let displays: [DisplayReport]
}
struct ReportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func makeReport() throws -> Report {
    var count: UInt32 = 0
    let countResult = CGGetOnlineDisplayList(0, nil, &count)
    guard countResult == .success else { throw ReportError(message: "Could not count displays: \(countResult.rawValue)") }
    guard count > 0 else { return Report(displays: []) }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    let listResult = CGGetOnlineDisplayList(count, &ids, &count)
    guard listResult == .success else { throw ReportError(message: "Could not list displays: \(listResult.rawValue)") }
    let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
    var displays: [DisplayReport] = []
    for id in ids.prefix(Int(count)) {
        guard let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] else {
            throw ReportError(message: "Could not enumerate modes for display \(id)")
        }
        displays.append(DisplayReport(id: id, builtIn: CGDisplayIsBuiltin(id) != 0,
            main: id == CGMainDisplayID(), mirrorsDisplay: CGDisplayMirrorsDisplay(id),
            current: CGDisplayCopyDisplayMode(id).map(ModeReport.init),
            modes: modes.map(ModeReport.init)))
    }
    return Report(displays: displays)
}

do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(makeReport())
    data.append(10)
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
