// swift-tools-version: 5.9
import PackageDescription
import Foundation

// =============================================================================
// RunAnywhere SDK - Swift Package Manager Distribution
// =============================================================================
//
// This is the SINGLE Package.swift for both local development and SPM consumption.
//
// FOR EXTERNAL USERS (consuming via GitHub):
//   .package(url: "https://github.com/RunanywhereAI/runanywhere-sdks", from: "0.17.0")
//
// FOR LOCAL DEVELOPMENT:
//   1. Run: cd sdk/runanywhere-swift && ./scripts/build-swift.sh --setup
//   2. Open the example app in Xcode
//   3. The app references this package via relative path
//
// =============================================================================

// Get the package directory for relative path resolution
let packageDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path

// Path to bundled ONNX Runtime dylib with CoreML support (for macOS)
let onnxRuntimeMacOSPath = "\(packageDir)/sdk/runanywhere-swift/Binaries/onnxruntime-macos"

// =============================================================================
// BINARY TARGET CONFIGURATION
// =============================================================================
//
// useLocalBinaries = true  → Use local XCFrameworks from sdk/runanywhere-swift/Binaries/
//                            For local development. Run first-time setup:
//                              cd sdk/runanywhere-swift && ./scripts/build-swift.sh --setup
//
// useLocalBinaries = false → Download XCFrameworks from GitHub releases (PRODUCTION)
//                            For external users via SPM. No setup needed.
//
// To toggle this value, use:
//   ./scripts/build-swift.sh --set-local   (sets useLocalBinaries = true)
//   ./scripts/build-swift.sh --set-remote  (sets useLocalBinaries = false)
//
// =============================================================================
let useLocalBinaries = false  // Toggle: true for local dev, false for release

// Version for remote XCFrameworks (used when testLocal = false)
// Updated automatically by CI/CD during releases
let sdkVersion = "0.17.5"

let package = Package(
    name: "runanywhere-sdks",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        // =================================================================
        // Core SDK - always needed
        // =================================================================
        .library(
            name: "RunAnywhere",
            targets: ["RunAnywhere"]
        ),

        // =================================================================
        // ONNX Runtime Backend - adds STT/TTS/VAD capabilities
        // =================================================================
        .library(
            name: "RunAnywhereONNX",
            targets: ["ONNXRuntime"]
        ),

        // =================================================================
        // LlamaCPP Backend - adds LLM text generation
        // =================================================================
        .library(
            name: "RunAnywhereLlamaCPP",
            targets: ["LlamaCPPRuntime"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.3.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "5.6.0"),
        .package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.8.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.40.0"),
    ],
    targets: [
        // =================================================================
        // C Bridge Module - Core Commons
        // =================================================================
        .target(
            name: "CRACommons",
            dependencies: ["RACommonsBinary"],
            path: "sdk/runanywhere-swift/Sources/RunAnywhere/CRACommons",
            publicHeadersPath: "include"
        ),

        // =================================================================
        // C Bridge Module - LlamaCPP Backend Headers
        // =================================================================
        .target(
            name: "LlamaCPPBackend",
            dependencies: ["RABackendLlamaCPPBinary"],
            path: "sdk/runanywhere-swift/Sources/LlamaCPPRuntime/include",
            publicHeadersPath: "."
        ),

        // =================================================================
        // C Bridge Module - ONNX Backend Headers
        // =================================================================
        .target(
            name: "ONNXBackend",
            dependencies: ["RABackendONNXBinary", "ONNXRuntimeBinary"],
            path: "sdk/runanywhere-swift/Sources/ONNXRuntime/include",
            publicHeadersPath: "."
        ),

        // =================================================================
        // Core SDK
        // =================================================================
        .target(
            name: "RunAnywhere",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Files", package: "Files"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "DeviceKit", package: "DeviceKit"),
                .product(name: "SWCompression", package: "SWCompression"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                "CRACommons",
            ],
            path: "sdk/runanywhere-swift/Sources/RunAnywhere",
            exclude: ["CRACommons"],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),

        // =================================================================
        // ONNX Runtime Backend
        // =================================================================
        .target(
            name: "ONNXRuntime",
            dependencies: [
                "RunAnywhere",
                "ONNXBackend",
            ],
            path: "sdk/runanywhere-swift/Sources/ONNXRuntime",
            exclude: ["include"],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreML"),
                .linkedLibrary("archive"),
                .linkedLibrary("bz2"),
            ]
        ),

        // =================================================================
        // LlamaCPP Runtime Backend
        // =================================================================
        .target(
            name: "LlamaCPPRuntime",
            dependencies: [
                "RunAnywhere",
                "LlamaCPPBackend",
            ],
            path: "sdk/runanywhere-swift/Sources/LlamaCPPRuntime",
            exclude: ["include"],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
            ]
        ),

    ] + binaryTargets()
)

// =============================================================================
// BINARY TARGET SELECTION
// =============================================================================
// Returns local or remote binary targets based on useLocalBinaries setting
func binaryTargets() -> [Target] {
    if useLocalBinaries {
        // =====================================================================
        // LOCAL DEVELOPMENT MODE
        // Use XCFrameworks from sdk/runanywhere-swift/Binaries/
        // Run: cd sdk/runanywhere-swift && ./scripts/build-swift.sh --setup
        // =====================================================================
        return [
            .binaryTarget(
                name: "RACommonsBinary",
                path: "sdk/runanywhere-swift/Binaries/RACommons.xcframework"
            ),
            .binaryTarget(
                name: "RABackendLlamaCPPBinary",
                path: "sdk/runanywhere-swift/Binaries/RABackendLLAMACPP.xcframework"
            ),
            .binaryTarget(
                name: "RABackendONNXBinary",
                path: "sdk/runanywhere-swift/Binaries/RABackendONNX.xcframework"
            ),
            .binaryTarget(
                name: "ONNXRuntimeBinary",
                url: "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.17.1.zip",
                checksum: "9a2d54d4f503fbb82d2f86361a1d22d4fe015e2b5e9fb419767209cc9ab6372c"
            ),
        ]
    } else {
        // =====================================================================
        // PRODUCTION MODE (for external SPM consumers)
        // Download XCFrameworks from GitHub releases (v* or swift-v* from Phase 2 CI)
        // =====================================================================
        return [
            .binaryTarget(
                name: "RACommonsBinary",
                url: "https://github.com/RunanywhereAI/runanywhere-sdks/releases/download/v\(sdkVersion)/RACommons-ios-v\(sdkVersion).zip",
                checksum: "8a5956ccf92ebb7745619e7bcdd226903bc497ff21c115e6e261f063ecf625f4"
            ),
            .binaryTarget(
                name: "RABackendLlamaCPPBinary",
                url: "https://github.com/RunanywhereAI/runanywhere-sdks/releases/download/v\(sdkVersion)/RABackendLLAMACPP-ios-v\(sdkVersion).zip",
                checksum: "bd7243d3eb9c90fe380ad1fd5c1b3331f5685021fa7de69b7e2184c7a3bfe0b7"
            ),
            .binaryTarget(
                name: "RABackendONNXBinary",
                url: "https://github.com/RunanywhereAI/runanywhere-sdks/releases/download/v\(sdkVersion)/RABackendONNX-ios-v\(sdkVersion).zip",
                checksum: "2456b103d76ce7f8e5b8d60daecee7ebea4ccb861c9ac9316798d52b7b76cf18"
            ),
            .binaryTarget(
                name: "ONNXRuntimeBinary",
                url: "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.17.1.zip",
                checksum: "9a2d54d4f503fbb82d2f86361a1d22d4fe015e2b5e9fb419767209cc9ab6372c"
            ),
        ]
    }
}
