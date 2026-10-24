// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameLauncher",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GameLauncher", targets: ["GameLauncherUI"]),
        .executable(name: "GameRunner", targets: ["GameRunner"]),
        .executable(name: "GameDisplayTest", targets: ["GameDisplayTest"]),
        .executable(name: "blackbars", targets: ["BlackBars"])
    ],
    targets: [
        .target(name: "LauncherCore", resources: [.process("Resources")]),
        .target(name: "CursorBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreFoundation")]),
        .target(name: "LauncherRuntime", dependencies: ["LauncherCore", "CursorBridge"]),
        .executableTarget(name: "GameDisplayTest", dependencies: ["LauncherRuntime"]),
        .executableTarget(name: "GameLauncherUI", dependencies: ["LauncherCore", "LauncherRuntime"]),
        .executableTarget(name: "GameRunner", dependencies: ["LauncherCore", "LauncherRuntime"]),
        .executableTarget(name: "BlackBars", path: "Sources/BlackBars"),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherRuntimeTests", dependencies: ["LauncherRuntime", "LauncherCore"])
    ]
)
