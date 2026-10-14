// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Portico",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Portico", targets: ["Portico"]),
        .library(name: "PorticoCore", targets: ["PorticoCore"])
    ],
    targets: [
        .target(name: "PorticoCore"),
        .executableTarget(name: "Portico", dependencies: ["PorticoCore"]),
        .testTarget(name: "PorticoCoreTests", dependencies: ["PorticoCore"])
    ]
)
