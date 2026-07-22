// swift-tools-version: 6.0

import PackageDescription

let commandLineToolsFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let commandLineToolsLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let testingSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-F", commandLineToolsFrameworks]),
]
let testingLinkerSettings: [LinkerSetting] = [
    .unsafeFlags([
        "-F", commandLineToolsFrameworks,
        "-Xlinker", "-rpath",
        "-Xlinker", commandLineToolsFrameworks,
        "-Xlinker", "-rpath",
        "-Xlinker", commandLineToolsLibraries,
    ]),
    .linkedFramework("Testing"),
]

let package = Package(
    name: "Meetco",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MeetcoCore", targets: ["MeetcoCore"]),
        .library(name: "MeetcoCapture", targets: ["MeetcoCapture"]),
        .executable(name: "MeetcoApp", targets: ["MeetcoApp"]),
        .executable(name: "MeetcoMCP", targets: ["MeetcoMCP"]),
        .executable(name: "MeetcoChecks", targets: ["MeetcoChecks"]),
    ],
    targets: [
        .target(name: "MeetcoCore"),
        .target(name: "MeetcoCapture", dependencies: ["MeetcoCore"]),
        .executableTarget(name: "MeetcoApp", dependencies: ["MeetcoCore", "MeetcoCapture"]),
        .executableTarget(name: "MeetcoMCP", dependencies: ["MeetcoCore"]),
        .executableTarget(name: "MeetcoChecks", dependencies: ["MeetcoCore", "MeetcoCapture"]),
        .testTarget(
            name: "MeetcoCoreTests",
            dependencies: ["MeetcoCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
        .testTarget(
            name: "MeetcoCaptureTests",
            dependencies: ["MeetcoCapture", "MeetcoCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
        .testTarget(
            name: "MeetcoAppTests",
            dependencies: ["MeetcoApp", "MeetcoCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
