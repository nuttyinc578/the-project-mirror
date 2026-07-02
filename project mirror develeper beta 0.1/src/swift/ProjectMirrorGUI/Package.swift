// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectMirrorGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ProjectMirrorGUI", targets: ["ProjectMirrorGUI"])
    ],
    targets: [
        .executableTarget(name: "ProjectMirrorGUI")
    ]
)
