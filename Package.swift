// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "222",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.executable(name: "222", targets: ["App"])],
    dependencies: [.package(url: "https://github.com/smirea/feedback-engine", branch: "master")],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [.product(name: "Feedback", package: "feedback-engine")],
            resources: [.process("Assets.xcassets")]
        ),
    ]
)
