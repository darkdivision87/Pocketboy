// swift-tools-version: 5.9
import PackageDescription

// Builds the PocketCore engine and every cartridge to a WebAssembly reactor module.
// See ../../.github/workflows/pocketboy-web.yml for the exact build command.
let reactor: [String] = [
    "-Xclang-linker", "-mexec-model=reactor",
    "-Xlinker", "-z", "-Xlinker", "stack-size=1048576",
    "-Xlinker", "--strip-all"
]

let package = Package(
    name: "PocketWeb",
    products: [
        .executable(name: "PocketWeb", targets: ["PocketWeb"])
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "PocketWeb",
            dependencies: [.product(name: "PocketCore", package: "PocketBoy")],
            path: "Sources/PocketWeb",
            linkerSettings: [.unsafeFlags(reactor)]
        )
    ]
)
