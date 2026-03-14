// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "test",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "test",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.test",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .camera(intentDescriptions: ["ログブックをスキャンするために使用します"])
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
