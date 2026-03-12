// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "test",
    platforms: [
        .iOS(.v18)
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
