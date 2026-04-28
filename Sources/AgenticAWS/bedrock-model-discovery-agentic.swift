import Agentic
import Foundation

extension BedrockModelDiscovery: AgentModelProfileDiscovery {
    public var source: AgentModelProfileSourceIdentifier {
        "aws_bedrock"
    }

    public func snapshot(
        request: AgentModelProfileDiscoveryRequest
    ) async throws -> AgentModelProfileSnapshot {
        try await profileSnapshot(
            options: .default,
            request: request
        )
    }
}

public extension BedrockModelDiscovery {
    func profileSnapshot(
        options: BedrockModelDiscoveryOptions = .default,
        request: AgentModelProfileDiscoveryRequest = .manual
    ) async throws -> AgentModelProfileSnapshot {
        let handles = try await handles(
            options: options
        )
        let profiles = profiles(
            from: handles
        )

        return .init(
            source: source,
            createdAt: Date(),
            profiles: profiles,
            metadata: [
                "provider": "aws",
                "adapter": "bedrock_converse",
                "region": control.region,
                "handle_count": String(
                    handles.count
                ),
                "refresh_reason": request.reason.rawValue
            ]
        )
    }

    func profiles(
        from handles: [BedrockModelHandle],
        adapterIdentifier: AgentModelAdapterIdentifier = .aws_bedrock,
        purposes: Set<AgentModelRoutePurpose> = [
            .executor,
            .advisor,
            .reviewer,
            .summarizer,
            .classifier,
            .extractor,
            .coder
        ],
        capabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming,
            .structured_output,
            .reasoning
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud
    ) -> [AgentModelProfile] {
        handles.map { handle in
            BedrockModelProfiles.profile(
                handle: handle,
                adapterIdentifier: adapterIdentifier,
                purposes: purposes,
                capabilities: capabilities,
                cost: cost,
                latency: latency,
                privacy: privacy
            )
        }
    }
}
