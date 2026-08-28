import Agentic
import AgenticExecution

public struct BedrockModelDiscoveryToolProvider: AgentToolProvider {
    public var discovery: BedrockModelDiscovery

    public init(
        discovery: BedrockModelDiscovery
    ) {
        self.discovery = discovery
    }

    public static func resolve() throws -> Self {
        try .init(
            discovery: .resolve()
        )
    }

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            BedrockModelDiscoveryToolSet(
                discovery: discovery
            )
        )
    }
}
