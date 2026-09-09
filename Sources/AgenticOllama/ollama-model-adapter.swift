import Agentic
import Foundation
import Milieu

public struct OllamaModelAdapter: AgentModelAdapter {
    private let provider: OllamaModelResponseProvider

    public init(
        configuration: OllamaModelConfiguration
    ) throws {
        self.init(
            configuration: configuration,
            trust: try OllamaURLSessionTrust.resolve(
                for: configuration.endpoint
            )
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
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws {
        let configuration = try OllamaModelConfiguration(
            endpoint: endpoint,
            contextWindow: contextWindow,
            thinking: thinking,
            metadata: metadata
        )

        try self.init(
            configuration: configuration
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static func resolve(
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
            contextWindow: contextWindow,
            thinking: thinking,
            metadata: metadata
        )

        return try .init(
            configuration: configuration
        )
    }
}

public struct OllamaModelResponseProvider:
    AgentModelResponseProviding
{
    public let configuration: OllamaModelConfiguration
    let trust: OllamaURLSessionTrust

    public init(
        configuration: OllamaModelConfiguration
    ) throws {
        self.configuration = configuration
        self.trust = try OllamaURLSessionTrust.resolve(
            for: configuration.endpoint
        )
    }

    init(
        configuration: OllamaModelConfiguration,
        trust: OllamaURLSessionTrust
    ) {
        self.configuration = configuration
        self.trust = trust
    }

    public func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let selectedModel = route.profile.model
        let mapped = try OllamaRequestMapper.map(
            request,
            model: selectedModel,
            configuration: configuration,
            stream: false
        )

        var metadata = configuration.metadata
        metadata["provider"] =
            metadata["provider"] ?? "ollama"
        metadata["adapter"] =
            metadata["adapter"] ?? "ollama_chat"
        metadata["model"] = selectedModel
        metadata["delivery"] = "buffered"

        let runtime = OllamaURLSessionRuntime(
            trust: trust,
            timeoutseconds: request.invocationoptions?.timeoutseconds
        )
        let response = try await runtime.respond(
            mapped,
            endpoint: configuration.endpoint
        )

        var accumulator = OllamaStreamAccumulator(
            metadata: metadata
        )
        _ = accumulator.consume(response)

        return try accumulator.completedResponse()
    }

    public func stream(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let selectedModel = route.profile.model
                    let mapped = try OllamaRequestMapper.map(
                        request,
                        model: selectedModel,
                        configuration: configuration,
                        stream: true
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

                    let runtime = OllamaURLSessionRuntime(
                        trust: trust,
                        timeoutseconds: request.invocationoptions?.timeoutseconds
                    )

                    for try await chunk in runtime.stream(
                        mapped,
                        endpoint: configuration.endpoint
                    ) {
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
