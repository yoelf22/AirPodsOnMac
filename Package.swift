// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "airpods-fix",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AirPodsFixLib",
            path: "Sources/AirPodsFixLib",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "airpods-fix",
            dependencies: ["AirPodsFixLib"],
            path: "Sources/airpods-fix"
        ),
        // Swift Testing target. Requires Xcode (Testing.framework is bundled with Xcode,
        // not Command Line Tools). Use 'swift run run-tests' on CLT-only installs.
        .testTarget(
            name: "AirPodsFixLibTests",
            dependencies: ["AirPodsFixLib"],
            path: "Tests/AirPodsFixLibTests"
        ),
        // Standalone runner: 'swift run run-tests' works without Xcode.
        .executableTarget(
            name: "run-tests",
            dependencies: ["AirPodsFixLib"],
            path: "Tests/NameMatcherRunner"
        )
    ]
)
