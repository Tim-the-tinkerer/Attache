// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Attache",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Attache", targets: ["Attache"]),
        .library(name: "AttacheCore", targets: ["AttacheCore"]),
    ],
    targets: [
        .target(
            name: "AttacheCore",
            path: "Sources/AttacheCore"
        ),
        .executableTarget(
            name: "Attache",
            dependencies: ["AttacheCore"],
            path: "Sources/Attache"
        ),
        .executableTarget(
            name: "AttacheCheck",
            dependencies: ["AttacheCore"],
            path: "Tests/AttacheTests"
        ),
    ]
)
