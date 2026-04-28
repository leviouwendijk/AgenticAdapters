import Agentic

public struct AppleFoundationModelProfileProvider: AgentModelProfileProvider {
    public var adapterIdentifier: AgentModelAdapterIdentifier
    public var profileIdentifier: AgentModelProfileIdentifier

    public init(
        adapterIdentifier: AgentModelAdapterIdentifier = .apple_foundation_models,
        profileIdentifier: AgentModelProfileIdentifier = .apple_foundation_models
    ) {
        self.adapterIdentifier = adapterIdentifier
        self.profileIdentifier = profileIdentifier
    }

    public func profiles() throws -> [AgentModelProfile] {
        [
            .init(
                identifier: profileIdentifier,
                adapterIdentifier: adapterIdentifier,
                model: "foundation_models",
                title: "Apple Foundation Models",
                purposes: [
                    .executor,
                    .summarizer,
                    .classifier,
                    .extractor,
                    .local_private
                ],
                capabilities: [
                    .text,
                    .streaming
                ],
                cost: .free,
                latency: .low,
                privacy: .local_private,
                limits: .unknown,
                metadata: [
                    "provider": "apple",
                    "adapter": "foundation_models"
                ]
            )
        ]
    }
}

public extension AgentModelAdapterIdentifier {
    static let apple_foundation_models: Self = "apple_foundation_models"
}

public extension AgentModelProfileIdentifier {
    static let apple_foundation_models: Self = "apple_foundation_models"
}
