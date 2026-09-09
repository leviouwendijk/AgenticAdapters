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

    public let profiles: [AgentModelProfile]
    public let metadata: [String: String]
    public let diagnostics: BedrockDiagnostics

    private let runtime: (any BedrockModelRuntime)?

    public init(
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.runtime = nil
    }

    public init(
        runtime: any BedrockModelRuntime,
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.runtime = runtime
    }

    public var adapter: AgentModelAdapterFactory? {
        let metadata = metadata
        let diagnostics = diagnostics

        if let runtime {
            return .init {
                BedrockModelAdapter(
                    runtime: runtime,
                    metadata: metadata,
                    diagnostics: diagnostics
                )
            }
        }

        return .init {
            try BedrockModelAdapter.resolve(
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
