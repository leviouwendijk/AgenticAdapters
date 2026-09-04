import Agentic

/// Installable Agentic model-provider composition for Ollama.
///
/// Endpoint resolution remains inside `OllamaModelAdapter.resolve()`, which
/// reads `AGENTIC_MODEL_OLLAMA_ENDPOINT` through Milieu. Consumers such as the
/// CLI only need to install this provider; they do not need to know Ollama's
/// transport or endpoint configuration details.
public struct OllamaModelProvider: AgentModelProvider {
    public let descriptor = AgentModelProviderDescriptor(
        source: "ollama",
        adapterIdentifier: .ollama,
        displayName: "Ollama",
        metadata: [
            "provider": "ollama",
            "privacy": "local_private",
        ]
    )

    public init() {}

    public var adapter: AgentModelAdapterFactory? {
        .init {
            try OllamaModelAdapter.resolve()
        }
    }

    public var profileProvider:
        (any AgentModelProfileProvider)?
    {
        OllamaModelProfileProvider()
    }
}
