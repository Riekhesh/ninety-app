// swift-tools-version: 6.0
import PackageDescription

// The engine is a standalone package so it can be tested on the command line
// without a simulator, and ported to the server before any leaderboard ships —
// the hard gate on Phase 4 (ADR 0006). Note what is NOT here: no dependencies
// at all. Data in, score out.
let package = Package(
    name: "RankingEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RankingEngine",
            targets: [
                "RankingEngine",
            ]
        ),
    ],
    targets: [
        .target(
            name: "RankingEngine",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "RankingEngineTests",
            dependencies: [
                "RankingEngine",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
