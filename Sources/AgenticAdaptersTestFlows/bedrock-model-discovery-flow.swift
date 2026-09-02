import Agentic
import AgenticAWS
import AgenticModels
import AWSConnector
import TestFlows

extension AgenticAdaptersFlowTesting {
    static func runBedrockModelHandleProfileSynthesis() async throws -> [TestFlowDiagnostic] {
        let handle = bedrockFixtureHandles()[0]
        let profile = BedrockModelProfiles.profile(
            handle: handle,
            purposes: [
                .executor,
                .advisor
            ],
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output
            ]
        )

        try Expect.equal(
            profile.model,
            handle.invokeIdentifier,
            "profile model uses Bedrock invocation identifier"
        )
        try Expect.hasPrefix(
            profile.identifier.rawValue,
            "aws_bedrock:system_inference_profile:",
            "profile identifier prefix"
        )
        try Expect.equal(
            profile.adapterIdentifier,
            .aws_bedrock,
            "profile adapter identifier"
        )
        try Expect.true(
            profile.capabilities.contains(
                .streaming
            ),
            "streaming capability retained when handle streaming is unknown"
        )
        try Expect.equal(
            try Expect.notNil(
                profile.metadata["provider"],
                "provider metadata"
            ),
            "aws",
            "provider metadata"
        )
        try Expect.equal(
            try Expect.notNil(
                profile.metadata["adapter"],
                "adapter metadata"
            ),
            "bedrock_converse",
            "adapter metadata"
        )
        try Expect.equal(
            try Expect.notNil(
                profile.metadata["bedrock_handle_kind"],
                "handle kind metadata"
            ),
            "system_inference_profile",
            "handle kind metadata"
        )
        try Expect.equal(
            try Expect.notNil(
                profile.metadata["bedrock_invoke_identifier"],
                "invoke identifier metadata"
            ),
            handle.invokeIdentifier,
            "invoke identifier metadata"
        )

        return [
            .field(
                "profile_id",
                profile.identifier.rawValue
            ),
            .field(
                "model",
                profile.model
            ),
            .field(
                "metadata",
                profile.metadata
                    .map { key, value in
                        "\(key)=\(value)"
                    }
                    .sorted()
                    .joined(
                        separator: ","
                    )
            )
        ]
    }

    static func runBedrockNonStreamingHandleDropsStreamingCapability() async throws -> [TestFlowDiagnostic] {
        let handle = BedrockModelHandle(
            invokeIdentifier: "anthropic.claude-legacy-text-v1",
            kind: .foundation_model,
            region: "eu-west-1",
            title: "Legacy Text Fixture",
            provider: "Anthropic",
            sourceModelIdentifiers: [
                "anthropic.claude-legacy-text-v1"
            ],
            sourceModelArns: [
                "arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-legacy-text-v1"
            ],
            inputModalities: [
                "TEXT"
            ],
            outputModalities: [
                "TEXT"
            ],
            streaming: false,
            status: "ACTIVE"
        )

        let profile = BedrockModelProfiles.profile(
            handle: handle,
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output
            ]
        )

        try Expect.false(
            profile.capabilities.contains(
                .streaming
            ),
            "streaming capability removed for explicitly non-streaming handle"
        )
        try Expect.true(
            profile.capabilities.contains(
                .text
            ),
            "text capability retained"
        )
        try Expect.true(
            profile.capabilities.contains(
                .tool_use
            ),
            "tool capability retained"
        )

        return [
            .field(
                "profile_id",
                profile.identifier.rawValue
            ),
            .field(
                "capabilities",
                profile.capabilities
                    .map(\.rawValue)
                    .sorted()
                    .joined(
                        separator: ","
                    )
            )
        ]
    }

    static func runBedrockGenericSnapshotProviderCatalog() async throws -> [TestFlowDiagnostic] {
        let profiles = bedrockFixtureHandles().map { handle in
            BedrockModelProfiles.profile(
                handle: handle,
                purposes: [
                    .executor,
                    .advisor
                ],
                capabilities: [
                    .text,
                    .tool_use,
                    .streaming,
                    .structured_output,
                    .reasoning
                ]
            )
        }

        let snapshot = AgentModelProfileSnapshot(
            source: "aws_bedrock",
            profiles: profiles,
            metadata: [
                "provider": "aws",
                "adapter": "bedrock_converse",
                "fixture": "true"
            ]
        )
        let provider = snapshot.provider
        let providedProfiles = try provider.profiles()
        let catalog = try AgentModelProfileCatalog(
            snapshot: snapshot
        )
        let selected = try catalog.profile(
            profiles[0].identifier
        )

        try Expect.equal(
            providedProfiles.count,
            profiles.count,
            "snapshot provider profile count"
        )
        try Expect.equal(
            catalog.profilesByIdentifier.count,
            profiles.count,
            "snapshot catalog profile count"
        )
        try Expect.equal(
            selected.model,
            profiles[0].model,
            "catalog selected model"
        )
        try Expect.equal(
            selected.identifier,
            profiles[0].identifier,
            "catalog selected identifier"
        )

        return [
            .field(
                "source",
                snapshot.source.rawValue
            ),
            .field(
                "profile_count",
                String(
                    profiles.count
                )
            ),
            .section(
                "profiles",
                profiles.map { profile in
                    "\(profile.identifier.rawValue) -> \(profile.model)"
                }
            )
        ]
    }

    static func runBedrockDiscoveryToolRegistration() async throws -> [TestFlowDiagnostic] {
        let discovery = BedrockModelDiscovery(
            control: bedrockFixtureClient()
        )

        let directRegistry = try Agentic.tool.registry(
            toolSets: [
                BedrockModelDiscoveryToolSet(
                    discovery: discovery
                )
            ]
        )

        let providerRegistry = try Agentic.tool.registry(
            toolProviders: [
                BedrockModelDiscoveryToolProvider(
                    discovery: discovery
                )
            ]
        )

        let expectedNames = [
            "bedrock_list_discovered_profiles",
            "bedrock_list_model_handles",
            "bedrock_resolve_model_handle"
        ]

        try Expect.equal(
            directRegistry.count,
            expectedNames.count,
            "direct tool set registry count"
        )
        try Expect.equal(
            providerRegistry.count,
            expectedNames.count,
            "tool provider registry count"
        )

        for name in expectedNames {
            try Expect.notNil(
                directRegistry.tool(
                    named: name
                ),
                "direct registry contains \(name)"
            )
            try Expect.notNil(
                providerRegistry.tool(
                    named: name
                ),
                "provider registry contains \(name)"
            )
        }

        return [
            .field(
                "direct_registry_count",
                String(
                    directRegistry.count
                )
            ),
            .field(
                "provider_registry_count",
                String(
                    providerRegistry.count
                )
            ),
            .field(
                "tools",
                expectedNames.joined(
                    separator: ","
                )
            )
        ]
    }

    static func runBedrockLiveNestedProfileAPI() async throws -> [TestFlowDiagnostic] {
        try TestFlowSkip.unless(
            bedrockCanResolveAWSConfiguration(),
            "AWS credentials/region are unavailable for live Bedrock discovery."
        )

        let options = BedrockModelDiscoveryOptions(
            modelOutputModality: "TEXT",
            profileType: "SYSTEM_DEFINED",
            includeInactiveProfiles: false,
            includeLegacy: false,
            maxProfileResults: 25
        )

        let snapshot = try await AgenticAWS.model.profile.snapshot(
            options: options,
            request: .init(
                reason: .manual,
                metadata: [
                    "flow": "bedrock-live-nested-profile-api"
                ]
            )
        )
        let provider = try await AgenticAWS.model.profile.provider(
            options: options
        )
        let profiles = try provider.profiles()
        let catalog = try AgentModelProfileCatalog(
            providers: [
                provider
            ]
        )

        try Expect.equal(
            snapshot.source.rawValue,
            "aws_bedrock",
            "snapshot source"
        )
        try Expect.equal(
            try Expect.notNil(
                snapshot.metadata["provider"],
                "snapshot provider metadata"
            ),
            "aws",
            "snapshot provider metadata"
        )
        try Expect.notEmpty(
            snapshot.profiles,
            "snapshot profiles"
        )
        try Expect.notEmpty(
            profiles,
            "provider profiles"
        )
        try Expect.greaterThan(
            catalog.profilesByIdentifier.count,
            0,
            "catalog profile count"
        )

        return [
            .field(
                "snapshot_profile_count",
                String(
                    snapshot.profiles.count
                )
            ),
            .field(
                "provider_profile_count",
                String(
                    profiles.count
                )
            ),
            .field(
                "catalog_profile_count",
                String(
                    catalog.profilesByIdentifier.count
                )
            ),
            .field(
                "metadata",
                snapshot.metadata
                    .map { key, value in
                        "\(key)=\(value)"
                    }
                    .sorted()
                    .joined(
                        separator: ","
                    )
            )
        ]
    }
}

private func bedrockFixtureHandles() -> [BedrockModelHandle] {
    [
        BedrockModelHandle(
            invokeIdentifier: "eu.anthropic.claude-sonnet-4-20250514-v1:0",
            kind: .system_inference_profile,
            region: "eu-west-1",
            title: "Claude Sonnet 4 EU",
            provider: "Anthropic",
            sourceModelIdentifiers: [
                "anthropic.claude-sonnet-4-20250514-v1:0"
            ],
            sourceModelArns: [
                "arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-sonnet-4-20250514-v1:0"
            ],
            inputModalities: [
                "TEXT",
                "IMAGE"
            ],
            outputModalities: [
                "TEXT"
            ],
            streaming: nil,
            status: "ACTIVE",
            type: "SYSTEM_DEFINED"
        ),
        BedrockModelHandle(
            invokeIdentifier: "eu.amazon.nova-micro-v1:0",
            kind: .system_inference_profile,
            region: "eu-west-1",
            title: "Nova Micro EU",
            provider: "Amazon",
            sourceModelIdentifiers: [
                "amazon.nova-micro-v1:0"
            ],
            sourceModelArns: [
                "arn:aws:bedrock:eu-west-1::foundation-model/amazon.nova-micro-v1:0"
            ],
            inputModalities: [
                "TEXT"
            ],
            outputModalities: [
                "TEXT"
            ],
            streaming: true,
            status: "ACTIVE",
            type: "SYSTEM_DEFINED"
        )
    ]
}

private func bedrockFixtureClient() -> BedrockClient {
    BedrockClient(
        region: "eu-west-1",
        credentials: .init(
            accessKeyId: "fixture-access-key",
            secretAccessKey: "fixture-secret-key"
        ),
        host: "bedrock.eu-west-1.amazonaws.com"
    )
}

private func bedrockCanResolveAWSConfiguration() -> Bool {
    do {
        _ = try AWSRegion.resolve()
        _ = try AWSCredentials.resolve()

        return true
    } catch {
        return false
    }
}
