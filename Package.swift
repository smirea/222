// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "222",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.executable(name: "222", targets: ["App"])],
    targets: [.executableTarget(name: "App", resources: [.process("Assets.xcassets")])]
)
