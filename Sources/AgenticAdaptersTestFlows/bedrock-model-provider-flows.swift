import Agentic
import AgenticAWS
import AgenticModels
import AWSConnector
import TestFlows

extension AgenticAdaptersFlowTesting {
    static func runBedrockModelProviderCatalogRealization()
        async throws -> [TestFlowDiagnostic]
    {
        let model = "eu.anthropic.claude-sonnet-4-6"
        let profileID: AgentModelProfileIdentifier =
            "aws_bedrock:claude_sonnet_4.6"
        let provider = BedrockModelProvider(
            runtime: BedrockModelProviderFixtureRuntime(),
            defaultModelIdentifier: model,
            profiles: [
                BedrockModelProfiles.advisor(
                    model,
                    modelID: KnownModel.anthropic.`claude_sonnet_4.6`,
                    identifier: profileID,
                    title: "Claude Sonnet 4.6"
                ),
            ]
        )
        let catalogs = try await AgentModelCatalogs(
            modelProviders: [
                provider,
            ]
        )
        let profile = try catalogs.profiles.profile(
            profileID
        )

        _ = try catalogs.adapters.adapter(
            for: .aws_bedrock
        )

        try Expect.equal(
            profile.adapterIdentifier,
            AgentModelAdapterIdentifier.aws_bedrock,
            "Bedrock provider profile adapter identifier"
        )
        try Expect.equal(
            profile.model,
            model,
            "Bedrock provider concrete model selector"
        )
        try Expect.equal(
            profile.modelID,
            KnownModel.anthropic.`claude_sonnet_4.6`,
            "Bedrock provider semantic model identifier"
        )
        try Expect.equal(
            profile.title,
            "Claude Sonnet 4.6",
            "Bedrock provider profile title"
        )

        return [
            .field(
                "provider",
                provider.descriptor.displayName
            ),
            .field(
                "profile",
                profile.identifier.rawValue
            ),
            .field(
                "model",
                profile.model
            ),
            .field(
                "adapter",
                profile.adapterIdentifier.rawValue
            ),
        ]
    }
}

private struct BedrockModelProviderFixtureRuntime:
    BedrockModelRuntime
{
    func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
