// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CivCoach", platforms: [.macOS(.v13)], products: [.executable(name: "CivCoach", targets: ["CivCoach"])], targets: [.executableTarget(name: "CivCoach", resources: [.copy("Resources/queries.lua")]), .testTarget(name: "CivCoachTests", dependencies: ["CivCoach"], resources: [.copy("Fixtures")])])
