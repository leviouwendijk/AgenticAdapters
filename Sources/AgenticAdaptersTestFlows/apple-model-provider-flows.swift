import Agentic
import AgenticApple
import AgenticModels
import TestFlows

extension AgenticAdaptersFlowTesting {
    static func runAppleModelProviderCatalogRealization()
        async throws -> [TestFlowDiagnostic]
    {
        let provider = AppleFoundationModelProvider()
        let catalogs = try await AgentModelCatalogs(
            modelProviders: [
                provider,
            ]
        )
        let profile = try catalogs.profiles.profile(
            .apple_foundation_models
        )

        _ = try catalogs.adapters.adapter(
            for: .apple_foundation_models
        )

        try Expect.equal(
            profile.adapterIdentifier,
            AgentModelAdapterIdentifier.apple_foundation_models,
            "Apple provider profile adapter identifier"
        )
        try Expect.equal(
            profile.title,
            "Apple Foundation Models",
            "Apple provider profile title"
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
                "adapter",
                profile.adapterIdentifier.rawValue
            ),
        ]
    }
}
