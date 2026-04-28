import Agentic
import AWSConnector
import Foundation

public struct BedrockModelAdapter: AgentModelAdapter {
    private let provider: BedrockModelResponseProvider

    public init(
        runtime: any BedrockModelRuntime,
        defaultModelIdentifier: String,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.provider = .init(
            configuration: .init(
                runtime: runtime,
                defaultModelIdentifier: defaultModelIdentifier,
                metadata: metadata,
                diagnostics: diagnostics
            )
        )
    }

    public init(
        runtime: BedrockRuntimeClient,
        defaultModelIdentifier: String,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.init(
            runtime: runtime as any BedrockModelRuntime,
            defaultModelIdentifier: defaultModelIdentifier,
            metadata: metadata,
            diagnostics: diagnostics
        )
    }

    public init(
        configuration: BedrockModelConfiguration
    ) {
        self.provider = .init(
            configuration: configuration
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static func resolve(
        defaultModelIdentifier: String,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) throws -> Self {
        try .init(
            runtime: BedrockRuntimeClient.resolve(),
            defaultModelIdentifier: defaultModelIdentifier,
            metadata: metadata,
            diagnostics: diagnostics
        )
    }
}

public struct BedrockModelResponseProvider: AgentModelResponseProviding {
    public let configuration: BedrockModelConfiguration

    public init(
        configuration: BedrockModelConfiguration
    ) {
        self.configuration = configuration
    }

    public func buffered(
        request: AgentRequest
    ) async throws -> AgentResponse {
        var response: AgentResponse?

        for try await event in stream(
            request: request
        ) {
            if case .completed(let completed) = event {
                response = completed
            }
        }

        guard let response else {
            throw BedrockAdapterError.streamEndedWithoutResponse
        }

        return response
    }

    public func stream(
        request: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let model = BedrockRequestMapper.model(
                        request,
                        default: configuration.defaultModelIdentifier
                    )
                    let bedrock = try BedrockRequestMapper.map(
                        request
                    )

                    if configuration.diagnostics.raw {
                        try dumpBedrockRequest(
                            bedrock
                        )
                    }

                    let metadata = BedrockMetadata.base(
                        configuration.metadata,
                        model: model
                    )
                    var stream = BedrockStreamAccumulator(
                        metadata: metadata
                    )

                    for try await event in configuration.runtime.stream(
                        bedrock,
                        modelIdentifier: model
                    ) {
                        if Task.isCancelled {
                            continuation.finish(
                                throwing: CancellationError()
                            )
                            return
                        }

                        let outputs = try stream.consume(
                            event
                        )

                        for output in outputs {
                            continuation.yield(
                                output
                            )
                        }
                    }

                    try stream.requireCompleted()
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

    private func dumpBedrockRequest(
        _ request: Bedrock.Converse.Request
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        let data = try encoder.encode(
            request
        )

        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            return
        }

        fputs(
            "\n--- Bedrock Converse Request ---\n\(text)\n--- End Bedrock Converse Request ---\n",
            stderr
        )
    }
}

private enum BedrockMetadata {
    static func base(
        _ values: [String: String],
        model: String
    ) -> [String: String] {
        var metadata = values
        metadata["provider"] = metadata["provider"] ?? "aws"
        metadata["adapter"] = metadata["adapter"] ?? "bedrock_converse"
        metadata["model"] = model

        return metadata
    }
}
