import Agentic
import AgenticExecution
import Foundation

public struct BedrockListModelHandlesToolInput: Sendable, Codable, Hashable {
    public var modelProvider: String?
    public var modelOutputModality: String?
    public var profileType: String?
    public var includeInactiveProfiles: Bool
    public var includeLegacy: Bool
    public var maxProfileResults: Int?

    public init(
        modelProvider: String? = nil,
        modelOutputModality: String? = "TEXT",
        profileType: String? = nil,
        includeInactiveProfiles: Bool = false,
        includeLegacy: Bool = false,
        maxProfileResults: Int? = 100
    ) {
        self.modelProvider = modelProvider
        self.modelOutputModality = modelOutputModality
        self.profileType = profileType
        self.includeInactiveProfiles = includeInactiveProfiles
        self.includeLegacy = includeLegacy
        self.maxProfileResults = maxProfileResults
    }

    public var options: BedrockModelDiscoveryOptions {
        .init(
            modelProvider: modelProvider,
            modelOutputModality: modelOutputModality,
            profileType: profileType,
            includeInactiveProfiles: includeInactiveProfiles,
            includeLegacy: includeLegacy,
            maxProfileResults: maxProfileResults
        )
    }
}

public struct BedrockListModelHandlesToolOutput: Sendable, Codable, Hashable {
    public var region: String
    public var count: Int
    public var handles: [BedrockModelHandle]

    public init(
        region: String,
        count: Int,
        handles: [BedrockModelHandle]
    ) {
        self.region = region
        self.count = count
        self.handles = handles
    }
}

public struct BedrockListDiscoveredProfilesToolInput: Sendable, Codable, Hashable {
    public var modelProvider: String?
    public var modelOutputModality: String?
    public var profileType: String?
    public var includeInactiveProfiles: Bool
    public var includeLegacy: Bool
    public var maxProfileResults: Int?

    public init(
        modelProvider: String? = nil,
        modelOutputModality: String? = "TEXT",
        profileType: String? = nil,
        includeInactiveProfiles: Bool = false,
        includeLegacy: Bool = false,
        maxProfileResults: Int? = 100
    ) {
        self.modelProvider = modelProvider
        self.modelOutputModality = modelOutputModality
        self.profileType = profileType
        self.includeInactiveProfiles = includeInactiveProfiles
        self.includeLegacy = includeLegacy
        self.maxProfileResults = maxProfileResults
    }

    public var options: BedrockModelDiscoveryOptions {
        .init(
            modelProvider: modelProvider,
            modelOutputModality: modelOutputModality,
            profileType: profileType,
            includeInactiveProfiles: includeInactiveProfiles,
            includeLegacy: includeLegacy,
            maxProfileResults: maxProfileResults
        )
    }
}

public struct BedrockListDiscoveredProfilesToolOutput: Sendable, Codable, Hashable {
    public var region: String
    public var handleCount: Int
    public var profileCount: Int
    public var handles: [BedrockModelHandle]
    public var profiles: [AgentModelProfile]

    public init(
        region: String,
        handleCount: Int,
        profileCount: Int,
        handles: [BedrockModelHandle],
        profiles: [AgentModelProfile]
    ) {
        self.region = region
        self.handleCount = handleCount
        self.profileCount = profileCount
        self.handles = handles
        self.profiles = profiles
    }
}

public struct BedrockResolveModelHandleToolInput: Sendable, Codable, Hashable {
    public var query: String
    public var modelProvider: String?
    public var modelOutputModality: String?
    public var profileType: String?
    public var includeInactiveProfiles: Bool
    public var includeLegacy: Bool
    public var maxProfileResults: Int?

    public init(
        query: String,
        modelProvider: String? = nil,
        modelOutputModality: String? = "TEXT",
        profileType: String? = nil,
        includeInactiveProfiles: Bool = false,
        includeLegacy: Bool = false,
        maxProfileResults: Int? = 100
    ) {
        self.query = query
        self.modelProvider = modelProvider
        self.modelOutputModality = modelOutputModality
        self.profileType = profileType
        self.includeInactiveProfiles = includeInactiveProfiles
        self.includeLegacy = includeLegacy
        self.maxProfileResults = maxProfileResults
    }

    public var options: BedrockModelDiscoveryOptions {
        .init(
            modelProvider: modelProvider,
            modelOutputModality: modelOutputModality,
            profileType: profileType,
            includeInactiveProfiles: includeInactiveProfiles,
            includeLegacy: includeLegacy,
            maxProfileResults: maxProfileResults
        )
    }
}

public struct BedrockResolveModelHandleToolOutput: Sendable, Codable, Hashable {
    public var query: String
    public var matchCount: Int
    public var matches: [BedrockModelHandle]

    public init(
        query: String,
        matchCount: Int,
        matches: [BedrockModelHandle]
    ) {
        self.query = query
        self.matchCount = matchCount
        self.matches = matches
    }
}

public struct BedrockModelDiscoveryToolSet: AgentToolSet {
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

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            [
                listModelHandlesTool(),
                listDiscoveredProfilesTool(),
                resolveModelHandleTool()
            ]
        )
    }
}

private extension BedrockModelDiscoveryToolSet {
    func listModelHandlesTool() -> ClosureAgentTool {
        tool(
            "bedrock_list_model_handles",
            input: BedrockListModelHandlesToolInput.self,
            output: BedrockListModelHandlesToolOutput.self,
            description: "List available AWS Bedrock model invocation handles from foundation models and inference profiles.",
            risk: .observe
        ) { input in
            let handles = try await discovery.handles(
                options: input.options
            )

            return BedrockListModelHandlesToolOutput(
                region: discovery.control.region,
                count: handles.count,
                handles: handles
            )
        }
    }

    func listDiscoveredProfilesTool() -> ClosureAgentTool {
        tool(
            "bedrock_list_discovered_profiles",
            input: BedrockListDiscoveredProfilesToolInput.self,
            output: BedrockListDiscoveredProfilesToolOutput.self,
            description: "List Agentic model profiles synthesized from AWS Bedrock model discovery.",
            risk: .observe
        ) { input in
            let handles = try await discovery.handles(
                options: input.options
            )
            let profiles = discovery.profiles(
                from: handles
            )

            return BedrockListDiscoveredProfilesToolOutput(
                region: discovery.control.region,
                handleCount: handles.count,
                profileCount: profiles.count,
                handles: handles,
                profiles: profiles
            )
        }
    }

    func resolveModelHandleTool() -> ClosureAgentTool {
        tool(
            "bedrock_resolve_model_handle",
            input: BedrockResolveModelHandleToolInput.self,
            output: BedrockResolveModelHandleToolOutput.self,
            description: "Find Bedrock model handles matching an invocation id, title, provider, source model id, or ARN substring.",
            risk: .observe
        ) { input in
            let query = input.query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let handles = try await discovery.handles(
                options: input.options
            )

            let matches = handles.filter { handle in
                guard !query.isEmpty else {
                    return true
                }

                return handle.matches(
                    query
                )
            }

            return BedrockResolveModelHandleToolOutput(
                query: query,
                matchCount: matches.count,
                matches: matches
            )
        }
    }
}

private extension BedrockModelHandle {
    func matches(
        _ query: String
    ) -> Bool {
        let normalizedQuery = query.lowercased()

        return searchableText.contains(
            normalizedQuery
        )
    }

    var searchableText: String {
        [
            invokeIdentifier,
            kind.rawValue,
            region,
            title ?? "",
            provider ?? "",
            status ?? "",
            type ?? "",
            sourceModelIdentifiers.joined(
                separator: " "
            ),
            sourceModelArns.joined(
                separator: " "
            ),
            inputModalities.joined(
                separator: " "
            ),
            outputModalities.joined(
                separator: " "
            )
        ].joined(
            separator: " "
        ).lowercased()
    }
}
