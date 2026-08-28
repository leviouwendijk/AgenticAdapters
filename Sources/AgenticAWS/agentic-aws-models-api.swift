import Agentic
import AgenticModels

public extension AgenticAWS {
    struct ModelAPI: Sendable {
        public init() {}

        public var tool: ToolAPI {
            .init()
        }

        public var profile: ProfileAPI {
            .init()
        }

        public func discovery() throws -> BedrockModelDiscovery {
            try .resolve()
        }

        public func handles(
            options: BedrockModelDiscoveryOptions = .default
        ) async throws -> [BedrockModelHandle] {
            try await discovery().handles(
                options: options
            )
        }
    }

    struct ModelToolAPI: Sendable {
        public init() {}

        public func set() throws -> BedrockModelDiscoveryToolSet {
            try .resolve()
        }

        public func provider() throws -> BedrockModelDiscoveryToolProvider {
            try .resolve()
        }
    }

    struct ModelProfileAPI: Sendable {
        public init() {}

        public func snapshot(
            options: BedrockModelDiscoveryOptions = .default,
            request: AgentModelProfileDiscoveryRequest = .manual
        ) async throws -> AgentModelProfileSnapshot {
            try await BedrockModelDiscovery
                .resolve()
                .profileSnapshot(
                    options: options,
                    request: request
                )
        }

        public func provider(
            options: BedrockModelDiscoveryOptions = .default,
            request: AgentModelProfileDiscoveryRequest = .manual
        ) async throws -> SnapshotAgentModelProfileProvider {
            try await snapshot(
                options: options,
                request: request
            ).provider
        }

        public func catalog(
            options: BedrockModelDiscoveryOptions = .default,
            request: AgentModelProfileDiscoveryRequest = .manual
        ) async throws -> AgentModelProfileCatalog {
            try await .init(
                snapshot: snapshot(
                    options: options,
                    request: request
                )
            )
        }
    }

    static let model: ModelAPI = .init()
}

public extension AgenticAWS.ModelAPI {
    typealias ToolAPI = AgenticAWS.ModelToolAPI
    typealias ProfileAPI = AgenticAWS.ModelProfileAPI
}
