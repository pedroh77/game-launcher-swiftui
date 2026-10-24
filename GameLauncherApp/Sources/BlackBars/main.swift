import AppKit

final class BarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

func makeBar(frame: NSRect) -> NSPanel {
    let panel = BarPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )

    panel.isOpaque = true
    panel.backgroundColor = .black
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.level = .screenSaver
    panel.collectionBehavior = [
        .canJoinAllSpaces,
        .stationary,
        .ignoresCycle,
        .fullScreenAuxiliary
    ]

    panel.orderFrontRegardless()
    return panel
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

guard let screen = NSScreen.main else {
    fputs("No main screen found.\n", stderr)
    exit(1)
}

let screenFrame = screen.frame
let barHeight: CGFloat = 80

let topBarFrame = NSRect(
    x: screenFrame.minX,
    y: screenFrame.maxY - barHeight,
    width: screenFrame.width,
    height: barHeight
)

let bottomBarFrame = NSRect(
    x: screenFrame.minX,
    y: screenFrame.minY,
    width: screenFrame.width,
    height: barHeight
)

let topBar = makeBar(frame: topBarFrame)
let bottomBar = makeBar(frame: bottomBarFrame)

app.run()

_ = topBar
_ = bottomBar
