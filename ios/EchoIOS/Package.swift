// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EchoIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "EchoCore", targets: ["EchoCore"]),
        .executable(name: "EchoCoreVerification", targets: ["EchoCoreVerification"])
    ],
    targets: [
        .target(
            name: "EchoCore",
            path: "Shared/EchoCore"
        ),
        .executableTarget(
            name: "EchoCoreVerification",
            dependencies: ["EchoCore"],
            path: "Verification"
        )
    ]
)
