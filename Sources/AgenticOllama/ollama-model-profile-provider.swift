import Agentic

/// First static Agentic model profile for the Ollama adapter.
///
/// This intentionally models only the configuration we have actually proven:
/// qwen3.5:9b, 32K operational context, text generation, native tool use, and
/// incremental streaming. Ollama model discovery can replace or supplement
/// this static profile later without changing the provider boundary.
public struct OllamaModelProfileProvider: AgentModelProfileProvider {
    public var adapterIdentifier: AgentModelAdapterIdentifier
    public var profileIdentifier: AgentModelProfileIdentifier
    public var model: String

    public init(
        adapterIdentifier: AgentModelAdapterIdentifier = .ollama,
        profileIdentifier: AgentModelProfileIdentifier = .ollama_qwen3_5_9b,
        model: String = "qwen3.5:9b"
    ) {
        self.adapterIdentifier = adapterIdentifier
        self.profileIdentifier = profileIdentifier
        self.model = model
    }

    public func profiles() throws -> [AgentModelProfile] {
        [
            .init(
                identifier: profileIdentifier,
                adapterIdentifier: adapterIdentifier,
                model: model,
                title: "Qwen 3.5 9B",
                purposes: [
                    .executor,
                    .planner,
                    .reviewer,
                    .summarizer,
                    .classifier,
                    .extractor,
                    .coder,
                    .local_private,
                ],
                capabilities: [
                    .text,
                    .tool_use,
                    .streaming,
                ],
                cost: .free,
                latency: .medium,
                privacy: .local_private,
                limits: .unknown,
                metadata: [
                    "provider": "ollama",
                    "adapter": "ollama_chat",
                    "context_window": "32768",
                    "thinking": "false",
                ]
            )
        ]
    }
}

public extension AgentModelAdapterIdentifier {
    static let ollama: Self = "ollama"
}

public extension AgentModelProfileIdentifier {
    static let ollama_qwen3_5_9b: Self = "ollama_qwen3_5_9b"
}
