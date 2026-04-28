import Agentic
import AWSConnector
import Foundation

public struct BedrockModelDiscovery: Sendable {
    public var control: BedrockClient

    public init(
        control: BedrockClient
    ) {
        self.control = control
    }

    public static func resolve() throws -> Self {
        .init(
            control: try BedrockClient.resolve()
        )
    }

    public func foundationModelHandles(
        options: BedrockModelDiscoveryOptions = .default
    ) async throws -> [BedrockModelHandle] {
        let models = try await control.models.listAll(
            .init(
                byOutputModality: options.modelOutputModality,
                byProvider: options.modelProvider
            )
        )

        return models
            .map {
                BedrockModelHandle(
                    model: $0,
                    region: control.region
                )
            }
            .filter {
                options.includeLegacy || !$0.isLegacy
            }
            .sorted(
                by: preferredHandleOrder
            )
    }

    public func inferenceProfileHandles(
        options: BedrockModelDiscoveryOptions = .default
    ) async throws -> [BedrockModelHandle] {
        let profiles = try await control.inferenceProfiles.listAll(
            .init(
                maxResults: options.maxProfileResults,
                typeEquals: options.profileType
            )
        )

        return profiles
            .filter { profile in
                options.includeInactiveProfiles
                    || profile.status.uppercased() == "ACTIVE"
            }
            .map {
                BedrockModelHandle(
                    profile: $0,
                    region: control.region
                )
            }
            .filter {
                options.includeLegacy || !$0.isLegacy
            }
            .sorted(
                by: preferredHandleOrder
            )
    }

    public func handles(
        options: BedrockModelDiscoveryOptions = .default
    ) async throws -> [BedrockModelHandle] {
        let profiles = try await inferenceProfileHandles(
            options: options
        )
        let models = try await foundationModelHandles(
            options: options
        )

        return profiles + models
    }

    public func profiles(
        options: BedrockModelDiscoveryOptions = .default,
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
    ) async throws -> [AgentModelProfile] {
        try await handles(
            options: options
        ).map { handle in
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

    public func snapshot(
        options: BedrockModelDiscoveryOptions = .default,
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
    ) async throws -> BedrockProfileSnapshot {
        let handles = try await handles(
            options: options
        )

        let profiles = handles.map { handle in
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

        return .init(
            region: control.region,
            createdAt: Date(),
            handles: handles,
            profiles: profiles
        )
    }
}

private extension BedrockModelDiscovery {
    func preferredHandleOrder(
        lhs: BedrockModelHandle,
        rhs: BedrockModelHandle
    ) -> Bool {
        if kindRank(
            lhs.kind
        ) != kindRank(
            rhs.kind
        ) {
            return kindRank(
                lhs.kind
            ) < kindRank(
                rhs.kind
            )
        }

        return lhs.invokeIdentifier < rhs.invokeIdentifier
    }

    func kindRank(
        _ kind: BedrockModelHandleKind
    ) -> Int {
        switch kind {
        case .system_inference_profile:
            return 0

        case .application_inference_profile:
            return 1

        case .inference_profile:
            return 2

        case .foundation_model:
            return 3
        }
    }
}
