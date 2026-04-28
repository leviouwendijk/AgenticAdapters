import Agentic

public extension AgenticAWS {
    struct ModelAPI: Sendable {
        public init() {}

        public func discovery() throws -> BedrockModelDiscovery {
            try .resolve()
        }

        public func toolSet() throws -> BedrockModelDiscoveryToolSet {
            try .resolve()
        }

        public func toolProvider() throws -> BedrockModelDiscoveryToolProvider {
            try .resolve()
        }

        public func snapshot(
            options: BedrockModelDiscoveryOptions = .default
        ) async throws -> BedrockProfileSnapshot {
            try await discovery().snapshot(
                options: options
            )
        }

        public func profileProvider(
            options: BedrockModelDiscoveryOptions = .default
        ) async throws -> BedrockDiscoveredProfileProvider {
            try await .init(
                snapshot: snapshot(
                    options: options
                )
            )
        }
    }

    static let model: ModelAPI = .init()
}
