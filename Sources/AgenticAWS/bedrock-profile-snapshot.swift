import Agentic
import Foundation

public struct BedrockProfileSnapshot: Sendable, Codable, Hashable {
    public var region: String
    public var createdAt: Date
    public var handles: [BedrockModelHandle]
    public var profiles: [AgentModelProfile]

    public init(
        region: String,
        createdAt: Date = Date(),
        handles: [BedrockModelHandle],
        profiles: [AgentModelProfile]
    ) {
        self.region = region
        self.createdAt = createdAt
        self.handles = handles
        self.profiles = profiles
    }
}

public struct BedrockDiscoveredProfileProvider: AgentModelProfileProvider {
    public var snapshot: BedrockProfileSnapshot

    public init(
        snapshot: BedrockProfileSnapshot
    ) {
        self.snapshot = snapshot
    }

    public func profiles() throws -> [AgentModelProfile] {
        snapshot.profiles
    }
}
