import Agentic

public struct AppleFoundationModelProvider:
    AgentModelProvider
{
    public let descriptor = AgentModelProviderDescriptor(
        source: "apple_foundation_models",
        adapterIdentifier: .apple_foundation_models,
        displayName: "Apple Foundation Models",
        metadata: [
            "provider": "apple",
            "privacy": "local_private",
        ]
    )

    public init() {}

    public var adapter: AgentModelAdapterFactory? {
        .init {
            AppleFoundationModelAdapter()
        }
    }

    public var profileProvider:
        (any AgentModelProfileProvider)?
    {
        AppleFoundationModelProfileProvider()
    }
}
