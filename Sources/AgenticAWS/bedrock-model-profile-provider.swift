import Agentic

public struct BedrockModelProfileProvider: AgentModelProfileProvider {
    public var adapterIdentifier: AgentModelAdapterIdentifier

    private let storedProfiles: [AgentModelProfile]

    public init(
        adapterIdentifier: AgentModelAdapterIdentifier = .aws_bedrock,
        profiles: [AgentModelProfile]
    ) {
        self.adapterIdentifier = adapterIdentifier
        self.storedProfiles = profiles
    }

    public init(
        adapterIdentifier: AgentModelAdapterIdentifier = .aws_bedrock,
        models: [String],
        defaultPurposes: Set<AgentModelRoutePurpose> = [
            .executor,
            .advisor,
            .reviewer,
            .summarizer,
            .classifier,
            .extractor,
            .coder
        ],
        defaultCapabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming,
            .structured_output,
            .reasoning
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud
    ) {
        self.adapterIdentifier = adapterIdentifier
        self.storedProfiles = models.map { model in
            BedrockModelProfiles.profile(
                model: model,
                adapterIdentifier: adapterIdentifier,
                purposes: defaultPurposes,
                capabilities: defaultCapabilities,
                cost: cost,
                latency: latency,
                privacy: privacy
            )
        }
    }

    public func profiles() throws -> [AgentModelProfile] {
        storedProfiles
    }
}

public enum BedrockModelProfiles {
    public static func profile(
        model: String,
        adapterIdentifier: AgentModelAdapterIdentifier = .aws_bedrock,
        purposes: Set<AgentModelRoutePurpose> = [
            .executor
        ],
        capabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud,
        limits: AgentModelLimits = .unknown,
        metadata: [String: String] = [:]
    ) -> AgentModelProfile {
        var metadata = metadata
        metadata["provider"] = metadata["provider"] ?? "aws"
        metadata["adapter"] = metadata["adapter"] ?? "bedrock_converse"

        return .init(
            identifier: .init(
                "aws_bedrock:\(model)"
            ),
            adapterIdentifier: adapterIdentifier,
            model: model,
            title: model,
            purposes: purposes,
            capabilities: capabilities,
            cost: cost,
            latency: latency,
            privacy: privacy,
            limits: limits,
            metadata: metadata
        )
    }

    public static func novaMicro(
        _ model: String = "eu.amazon.nova-micro-v1:0"
    ) -> AgentModelProfile {
        profile(
            model: model,
            purposes: [
                .executor,
                .summarizer,
                .classifier,
                .extractor
            ],
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output
            ],
            cost: .cheap,
            latency: .low,
            privacy: .private_cloud
        )
    }

    public static func advisor(
        _ model: String
    ) -> AgentModelProfile {
        profile(
            model: model,
            purposes: [
                .advisor,
                .reviewer,
                .coder
            ],
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output,
                .reasoning
            ],
            cost: .premium,
            latency: .medium,
            privacy: .private_cloud
        )
    }
}

public extension AgentModelAdapterIdentifier {
    static let aws_bedrock: Self = "aws_bedrock"
}
