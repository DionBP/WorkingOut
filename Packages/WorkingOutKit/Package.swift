// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkingOutKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "WorkingOutKit", targets: ["WorkingOutKit"])],
    targets: [
        .target(name: "WorkingOutKit"),
        .testTarget(name: "WorkingOutKitTests", dependencies: ["WorkingOutKit"])
    ]
)
