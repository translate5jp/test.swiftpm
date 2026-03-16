// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "LogbookScanner",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "LogbookScanner",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.logbook-scanner",
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
                .camera(purposeString: "ログブックをスキャンするために使用します")
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
