// swift-tools-version:5.9
//
// build.sh builds and signs the `teams-unfloat` binary. Signing matters: macOS
// ties the Accessibility permission to the binary's path and signature.

import PackageDescription

let package = Package(
    name: "teams-unfloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "teams-unfloat",
            path: "Sources/TeamsUnfloat",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .testTarget(
            name: "TeamsUnfloatTests",
            dependencies: ["teams-unfloat"],
            path: "Tests/TeamsUnfloatTests"
        ),
    ]
)
