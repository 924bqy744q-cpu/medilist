// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MedListCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MedListCore", targets: ["MedListCore"]),
        .executable(name: "medlist-eval", targets: ["medlist-eval"]),
    ],
    targets: [
        .target(
            name: "MedListCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "medlist-eval",
            dependencies: ["MedListCore"]
        ),
        .testTarget(
            name: "MedListCoreTests",
            dependencies: ["MedListCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
