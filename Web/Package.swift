// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Builds the PocketCore engine and every cartridge to a WebAssembly reactor module.
// See ../../.github/workflows/pocketboy-web.yml for the exact build command.
// Debug branches set PB_KEEP_SYMBOLS=1 so crash reports name the failing function; the shipped build strips them to stay small.
let keepSymbols: Bool = !(ProcessInfo.processInfo.environment["PB_KEEP_SYMBOLS"] ?? "").isEmpty
var reactor: [String] = [
    "-Xclang-linker", "-mexec-model=reactor",
    "-Xlinker", "-z", "-Xlinker", "stack-size=1048576"
]
if !keepSymbols { reactor += ["-Xlinker", "--strip-all"] }

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
