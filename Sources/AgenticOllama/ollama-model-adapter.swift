import Agentic
import Cryptography
import Foundation
import Milieu

public struct OllamaModelAdapter: AgentModelAdapter {
    private let provider: OllamaModelResponseProvider

    public init(
        configuration: OllamaModelConfiguration,
        session: URLSession = .shared
    ) {
        self.provider = .init(
            configuration: configuration,
            session: session
        )
    }

    public init(
        endpoint: URL,
        defaultModelIdentifier: String = "qwen3.5:9b",
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws {
        self.init(
            configuration: try .init(
                endpoint: endpoint,
                defaultModelIdentifier: defaultModelIdentifier,
                contextWindow: contextWindow,
                thinking: thinking,
                metadata: metadata
            )
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static func resolve(
        defaultModelIdentifier: String = "qwen3.5:9b",
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws -> Self {
        let rawEndpoint = try EnvironmentExtractor.value("AGENTIC_MODEL_OLLAMA_ENDPOINT")
        guard let endpoint = URL(string: rawEndpoint) else {
            throw OllamaAdapterError.invalidEndpoint(rawEndpoint)
        }
        let configuration = try OllamaModelConfiguration(
            endpoint: endpoint,
            defaultModelIdentifier: defaultModelIdentifier,
            contextWindow: contextWindow,
            thinking: thinking,
            metadata: metadata
        )

        let session: URLSession
        if endpoint.scheme?.lowercased() == "https",
           EnvironmentExtractor.optional(
               "AGENTIC_MODEL_OLLAMA_CA_CERTIFICATE_PATH"
           ) != nil {
            let trusted = try CryptographicCATrustedURLSession.create(
                caCertificatePathSymbol:
                    "AGENTIC_MODEL_OLLAMA_CA_CERTIFICATE_PATH",
                allowedHost: endpoint.host,
                anchorOnly: true,
                policyMode: .strictServerAuth
            )
            session = trusted.0
        } else {
            session = .shared
        }

        return .init(
            configuration: configuration,
            session: session
        )
    }
}

public struct OllamaModelResponseProvider: AgentModelResponseProviding {
    public let configuration: OllamaModelConfiguration
    let session: URLSession

    public init(
        configuration: OllamaModelConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    public func buffered(request: AgentRequest) async throws -> AgentResponse {
        var response: AgentResponse?
        for try await event in stream(request: request) {
            if case .completed(let completed) = event {
                response = completed
            }
        }
        guard let response else {
            throw OllamaAdapterError.streamEndedWithoutResponse
        }
        return response
    }

    public func stream(request: AgentRequest) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let mapped = try OllamaRequestMapper.map(
                        request,
                        configuration: configuration
                    )
                    let selectedModel = OllamaRequestMapper.model(
                        request,
                        default: configuration.defaultModelIdentifier
                    )
                    var metadata = configuration.metadata
                    metadata["provider"] = metadata["provider"] ?? "ollama"
                    metadata["adapter"] = metadata["adapter"] ?? "ollama_chat"
                    metadata["model"] = selectedModel
                    metadata["delivery"] = "stream"

                    var accumulator = OllamaStreamAccumulator(metadata: metadata)
                    let runtime = OllamaURLSessionRuntime(
                        session: session
                    )
                    for try await chunk in runtime.stream(mapped, endpoint: configuration.endpoint) {
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        for event in accumulator.consume(chunk) {
                            continuation.yield(event)
                        }
                    }
                    try accumulator.requireCompleted()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
