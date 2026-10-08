// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SloopStudio",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SloopStudio",
            targets: ["SloopStudio"]
        ),
    ],
    targets: [
        .target(
            name: "SloopStudio",
            path: "SloopStudio/Sources"
        )
    ]
)
