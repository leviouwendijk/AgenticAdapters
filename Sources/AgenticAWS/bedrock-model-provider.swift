import Agentic

public struct BedrockModelProvider:
    AgentModelProvider
{
    public let descriptor = AgentModelProviderDescriptor(
        source: "aws_bedrock",
        adapterIdentifier: .aws_bedrock,
        displayName: "AWS Bedrock",
        metadata: [
            "provider": "aws",
            "privacy": "private_cloud",
        ]
    )

    public let defaultModelIdentifier: String
    public let profiles: [AgentModelProfile]
    public let metadata: [String: String]
    public let diagnostics: BedrockDiagnostics

    private let runtime: (any BedrockModelRuntime)?

    public init(
        defaultModelIdentifier: String,
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.defaultModelIdentifier = defaultModelIdentifier
        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.runtime = nil
    }

    public init(
        runtime: any BedrockModelRuntime,
        defaultModelIdentifier: String,
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.defaultModelIdentifier = defaultModelIdentifier
        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.runtime = runtime
    }

    public var adapter: AgentModelAdapterFactory? {
        let defaultModelIdentifier = defaultModelIdentifier
        let metadata = metadata
        let diagnostics = diagnostics

        if let runtime {
            return .init {
                BedrockModelAdapter(
                    runtime: runtime,
                    defaultModelIdentifier: defaultModelIdentifier,
                    metadata: metadata,
                    diagnostics: diagnostics
                )
            }
        }

        return .init {
            try BedrockModelAdapter.resolve(
                defaultModelIdentifier: defaultModelIdentifier,
                metadata: metadata,
                diagnostics: diagnostics
            )
        }
    }

    public var profileProvider:
        (any AgentModelProfileProvider)?
    {
        BedrockModelProfileProvider(
            profiles: profiles
        )
    }
}
