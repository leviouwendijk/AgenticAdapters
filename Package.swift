// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgenticAdapters",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgenticApple", // FoundationModels framework
            targets: ["AgenticApple"]
        ),
        .library(
            name: "AgenticAWS", // Bedrock, perhaps later also transcribe etc?
            targets: ["AgenticAWS"]
        ),
        // .library(
        //     name: "AgenticOpenAI",
        //     targets: ["AgenticOpenAI"]
        // ),

        // .library(
        //     name: "AgenticAnthropic",
        //     targets: ["AgenticAnthropic"]
        // ),

        .library(
            name: "AgenticOllama",
            targets: ["AgenticOllama"]
        ),
        // ------------------------------------------
        // TEST TARGET
        .executable(
            name: "adaptest",
            targets: ["AgenticAdaptersTestFlows"]
        ),

    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticExecution.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticModels.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AWSConnector.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Cryptography.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/SchemaMacros.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),

        // .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.1"),

        // .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Parsers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Accounting.git", branch: "master"),

        // .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/FileTypes.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Selection.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Concatenation.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Interfaces.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Tokens.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Matching.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Ranking.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Fuzzy.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Executable.git", branch: "master"),
    ],

    targets: [
        .target(
            name: "AgenticApple",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
            ],
        ),
        .target(
            name: "AgenticAWS",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "AgenticModels", package: "AgenticModels"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "SchemaMacros", package: "SchemaMacros"),
            ],
        ),
        .target(
            name: "AgenticOllama",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Cryptography", package: "Cryptography"),
            ],
        ),
        .executableTarget(
            name: "AgenticAdaptersTestFlows",
            dependencies: [
                "AgenticApple",
                "AgenticAWS",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "AgenticModels"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
    // targets: [
    //     .target(
    //         name: "AgenticAdapters"
    //     ),
    //     .testTarget(
    //         name: "AgenticAdaptersTests",
    //         dependencies: ["AgenticAdapters"]
    //     ),
    // ]
)
