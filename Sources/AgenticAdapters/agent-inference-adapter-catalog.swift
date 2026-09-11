import AgenticInference

public struct AgentInferenceAdapterCatalog: Sendable {
    private var adapters: [
        AgentInferenceAdapterIdentifier:
            any AgentInferenceAdapter
    ]

    public init() {
        self.adapters = [:]
    }

    public init(
        adapters: [any AgentInferenceAdapter]
    ) throws {
        self.adapters = [:]

        for adapter in adapters {
            try register(
                adapter
            )
        }
    }

    public var count: Int {
        adapters.count
    }

    public var isEmpty: Bool {
        adapters.isEmpty
    }

    public var identifiers: [AgentInferenceAdapterIdentifier] {
        adapters.keys.sorted { lhs, rhs in
            lhs.rawValue < rhs.rawValue
        }
    }

    public mutating func register(
        _ adapter: any AgentInferenceAdapter
    ) throws {
        let identifier = adapter.identifier

        guard adapters[identifier] == nil else {
            throw AgentInferenceAdapterCatalogError.duplicateAdapter(
                identifier.rawValue
            )
        }

        adapters[identifier] = adapter
    }

    public func adapter(
        for identifier: AgentInferenceAdapterIdentifier
    ) -> (any AgentInferenceAdapter)? {
        adapters[identifier]
    }

    public func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
        guard let adapter = adapters[identifier] else {
            throw AgentInferenceAdapterCatalogError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}
