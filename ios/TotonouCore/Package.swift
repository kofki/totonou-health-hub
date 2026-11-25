// swift-tools-version: 6.0
import PackageDescription

// TotonouCore holds everything that is pure Swift: game rules, the design tokens,
// and the types shared between the app and the widget. No SwiftData, no networking.
// Because it has no app dependencies you can test it in seconds with `swift test`.
let package = Package(
    name: "TotonouCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TotonouCore", targets: ["TotonouCore"]),
    ],
    targets: [
        .target(name: "TotonouCore"),
        .testTarget(name: "TotonouCoreTests", dependencies: ["TotonouCore"]),
    ]
)
