// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MiniTools",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "MiniTools", targets: ["MiniTools"]),
        .executable(
            name: "MiniToolsInputSourceHelper",
            targets: ["MiniToolsInputSourceHelper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MiniTools",
            path: "Sources/MiniTools",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Vision")
            ]
        ),
        .executableTarget(
            name: "MiniToolsInputSourceHelper",
            path: "Sources/MiniToolsInputSourceHelper",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "MiniToolsTests",
            dependencies: ["MiniTools"],
            path: "Tests/MiniToolsTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
