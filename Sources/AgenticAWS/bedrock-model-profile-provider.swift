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
            .planner,
            .researcher,
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

    public init(
        adapterIdentifier: AgentModelAdapterIdentifier = .aws_bedrock,
        handles: [BedrockModelHandle],
        defaultPurposes: Set<AgentModelRoutePurpose> = [
            .executor,
            .planner,
            .researcher,
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
        self.storedProfiles = handles.map { handle in
            BedrockModelProfiles.profile(
                handle: handle,
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
        identifier: AgentModelProfileIdentifier? = nil,
        model: String,
        title: String? = nil,
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
            identifier: identifier ?? fallbackIdentifier(
                model: model
            ),
            adapterIdentifier: adapterIdentifier,
            model: model,
            title: title ?? model,
            purposes: purposes,
            capabilities: capabilities,
            cost: cost,
            latency: latency,
            privacy: privacy,
            limits: limits,
            metadata: metadata
        )
    }

    public static func profile(
        handle: BedrockModelHandle,
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
        profile(
            identifier: generatedIdentifier(
                for: handle
            ),
            model: handle.invokeIdentifier,
            title: handle.title,
            adapterIdentifier: adapterIdentifier,
            purposes: purposes,
            capabilities: effectiveCapabilities(
                capabilities,
                handle: handle
            ),
            cost: cost,
            latency: latency,
            privacy: privacy,
            limits: limits,
            metadata: handle.metadata(
                merging: metadata
            )
        )
    }

    public static func novaMicro(
        _ model: String = "eu.amazon.nova-micro-v1:0"
    ) -> AgentModelProfile {
        profile(
            identifier: .init(
                "aws_bedrock:nova_micro"
            ),
            model: model,
            title: "AWS Bedrock Nova Micro",
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
        _ model: String,
        identifier: AgentModelProfileIdentifier? = nil,
        title: String? = nil
    ) -> AgentModelProfile {
        profile(
            identifier: identifier,
            model: model,
            title: title,
            purposes: [
                .planner,
                .researcher,
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

private extension BedrockModelProfiles {
    static func fallbackIdentifier(
        model: String
    ) -> AgentModelProfileIdentifier {
        .init(
            "aws_bedrock:\(model)"
        )
    }

    static func generatedIdentifier(
        for handle: BedrockModelHandle
    ) -> AgentModelProfileIdentifier {
        .init(
            [
                "aws_bedrock",
                handle.kind.rawValue,
                safeIdentifierComponent(
                    handle.invokeIdentifier
                )
            ].joined(
                separator: ":"
            )
        )
    }

    static func safeIdentifierComponent(
        _ value: String
    ) -> String {
        value.map { character in
            if character.isLetter
                || character.isNumber
                || character == "-"
                || character == "_"
                || character == "." {
                return String(
                    character
                )
            }

            return "_"
        }.joined()
    }

    static func effectiveCapabilities(
        _ capabilities: Set<AgentModelCapability>,
        handle: BedrockModelHandle
    ) -> Set<AgentModelCapability> {
        guard handle.streaming == false else {
            return capabilities
        }

        var capabilities = capabilities
        capabilities.remove(
            .streaming
        )

        return capabilities
    }
}

public extension AgentModelAdapterIdentifier {
    static let aws_bedrock: Self = "aws_bedrock"
}
