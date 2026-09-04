import Agentic
import Cryptography
import Foundation
import Milieu

public struct OllamaModelAdapter: AgentModelAdapter {
    private let provider: OllamaModelResponseProvider

    public init(configuration: OllamaModelConfiguration) {
        self.init(
            configuration: configuration,
            trust: .system
        )
    }

    private init(
        configuration: OllamaModelConfiguration,
        trust: OllamaURLSessionTrust
    ) {
        self.provider = .init(
            configuration: configuration,
            trust: trust
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
        let rawEndpoint = try EnvironmentExtractor.value(
            "AGENTIC_MODEL_OLLAMA_ENDPOINT"
        )
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

        let trust: OllamaURLSessionTrust
        if endpoint.scheme?.lowercased() == "https" {
            let caSymbol =
                "AGENTIC_MODEL_OLLAMA_CA_CERTIFICATE_PATH"

            guard let caPath = EnvironmentExtractor.optional(
                .symbol(caSymbol)
            ) else {
                throw OllamaAdapterError
                    .missingTLSCACertificateConfiguration(
                        symbol: caSymbol
                    )
            }

            do {
                _ = try CryptographicTLSCertificateLoader
                    .loadCertificate(at: caPath)
            } catch {
                throw OllamaAdapterError.invalidTLSCACertificate(
                    path: caPath,
                    reason: error.localizedDescription
                )
            }

            trust = .privateCA(
                caCertificatePathSymbol: caSymbol
            )
        } else {
            trust = .system
        }

        return .init(
            configuration: configuration,
            trust: trust
        )
    }
}

public struct OllamaModelResponseProvider:
    AgentModelResponseProviding
{
    public let configuration: OllamaModelConfiguration
    let trust: OllamaURLSessionTrust

    public init(configuration: OllamaModelConfiguration) {
        self.configuration = configuration
        self.trust = .system
    }

    init(
        configuration: OllamaModelConfiguration,
        trust: OllamaURLSessionTrust
    ) {
        self.configuration = configuration
        self.trust = trust
    }

    public func buffered(
        request: AgentRequest
    ) async throws -> AgentResponse {
        var response: AgentResponse?
        for try await event in stream(request: request) {
            if case .completed(let completed) = event {
                response = completed
            }
        }
        guard let response else {
            throw OllamaAdapterError
                .streamEndedWithoutResponse
        }
        return response
    }

    public func stream(
        request: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let mapped = try OllamaRequestMapper.map(
                        request,
                        configuration: configuration
                    )
                    let selectedModel =
                        OllamaRequestMapper.model(
                            request,
                            default:
                                configuration
                                    .defaultModelIdentifier
                        )

                    var metadata = configuration.metadata
                    metadata["provider"] =
                        metadata["provider"] ?? "ollama"
                    metadata["adapter"] =
                        metadata["adapter"] ?? "ollama_chat"
                    metadata["model"] = selectedModel
                    metadata["delivery"] = "stream"

                    var accumulator =
                        OllamaStreamAccumulator(
                            metadata: metadata
                        )
                    let runtime =
                        OllamaURLSessionRuntime(
                            trust: trust
                        )

                    for try await chunk in runtime.stream(
                        mapped,
                        endpoint: configuration.endpoint
                    ) {
                        if Task.isCancelled {
                            throw CancellationError()
                        }

                        for event in accumulator.consume(
                            chunk
                        ) {
                            continuation.yield(event)
                        }
                    }

                    try accumulator.requireCompleted()
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
