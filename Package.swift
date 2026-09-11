// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticAdapters",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AgenticAdapters",
            targets: [
                "AgenticAdapters",
            ]
        ),
        .executable(
            name: "adaptest",
            targets: [
                "AgenticAdaptersTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Agentic.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/AgenticInference.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "AgenticAdapters",
            dependencies: [
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "AgenticInference",
                    package: "AgenticInference"
                ),
            ]
        ),
        .executableTarget(
            name: "AgenticAdaptersTestFlows",
            dependencies: [
                "AgenticAdapters",
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "AgenticInference",
                    package: "AgenticInference"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
