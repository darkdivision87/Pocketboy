// swift-tools-version: 5.9
import PackageDescription

// Games that are still being written. They live in the repository but are kept out of the build until they are
// finished and registered in Library.swift; delete a line here when its game is ready. This keeps a half-written
// file from blocking the build (and the website deploy).
let wipFiles: [String] = [
    "Games/LanternAudio.swift",
    "Games/LanternSave.swift",
    "Games/LanternArt.swift",
    "Games/LanternWorld.swift",
    "Games/TycoonData.swift",
    "Games/TycoonTown64.swift"
]

let package = Package(
    name: "PocketBoy",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "PocketCore", targets: ["PocketCore"])
    ],
    targets: [
        .target(name: "PocketCore", path: "Sources/PocketCore", exclude: wipFiles),
        .testTarget(name: "PocketCoreTests", dependencies: ["PocketCore"], path: "Tests/PocketCoreTests")
    ]
)
