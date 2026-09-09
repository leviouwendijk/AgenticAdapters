import Agentic
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationModelAdapter: AgentModelAdapter {
    private let provider: AppleFoundationModelResponseProvider

    public init() {
        self.provider = .init()
    }

    public var response: AgentModelResponseProviding {
        provider
    }
}

public struct AppleFoundationModelResponseProvider: AgentModelResponseProviding {
    public init() {}

    public func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let invocation = try AppleFoundationModelInvocation(
            parsing: request,
            route: route,
            context: context
        )

        let text = try await generate(
            invocation
        )

        return AgentResponse(
            message: .init(
                role: .assistant,
                text: text
            ),
            stopReason: .end_turn,
            usage: nil,
            metadata: [
                "provider": "apple",
                "adapter": "foundation_models",
                "model": invocation.selectedModelIdentifier,
                "delivery": "buffered"
            ]
        )
    }

    public func stream(
        request: AgentRequest,
        route: AgentModelRoute,
        context: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bufferedResponse = try await buffered(
                        request: request,
                        route: route,
                        context: context
                    )
                    let response = AgentResponse(
                        message: bufferedResponse.message,
                        stopReason: bufferedResponse.stopReason,
                        usage: bufferedResponse.usage,
                        metadata: bufferedResponse.metadata.merging(
                            [
                                "delivery": "stream",
                                "streaming": "buffered_fallback"
                            ]
                        ) { _, new in
                            new
                        }
                    )

                    for block in response.message.content.blocks {
                        switch block {
                        case .text(let text) where !text.isEmpty:
                            continuation.yield(
                                .messagedelta(.text(text))
                            )

                        case .tool_call:
                            continuation.yield(
                                .messagedelta(block)
                            )

                        default:
                            continue
                        }
                    }

                    continuation.yield(
                        .completed(response)
                    )
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

private extension AppleFoundationModelResponseProvider {
    func generate(
        _ invocation: AppleFoundationModelInvocation
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(
                invocation
            )
        } else {
            throw AppleFoundationModelError.operatingSystemUnavailable
        }
        #else
        throw AppleFoundationModelError.foundationModelsUnavailable
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    func generateWithFoundationModels(
        _ prepared: AppleFoundationModelInvocation
    ) async throws -> String {
        let request = prepared.request
        let resolver = prepared.context.toolCallResolver
        let model: SystemLanguageModel

        switch prepared.model {
        case .system:
            model = .default
        }

        switch model.availability {
        case .available:
            break

        case .unavailable(let reason):
            throw AppleFoundationModelError.modelUnavailable(
                String(describing: reason)
            )
        }

        do {
            let bridgedTools: [AppleFoundationModelToolProxy]

            if request.tools.isEmpty {
                bridgedTools = []
            } else {
                guard let resolver else {
                    throw AppleFoundationModelError.toolResolverUnavailable(
                        request.tools.map { tool in
                            tool.name
                        }
                    )
                }

                bridgedTools = try AppleFoundationModelToolBridge.tools(
                    for: request.tools,
                    resolver: resolver
                )
            }

            let invocation = try AppleFoundationModelTranscriptMapper.invocation(
                for: request,
                tools: bridgedTools
            )
            let session = LanguageModelSession(
                model: model,
                tools: bridgedTools,
                transcript: invocation.transcript
            )
            let responseFormat = try AppleFoundationModelResponseFormat(
                parsing: request.responseFormat
            )

            switch responseFormat {
            case .text:
                let response = try await session.respond(
                    to: invocation.prompt
                )

                return response.content.trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines
                )

            case .jsonschema(let schema):
                let response = try await session.respond(
                    to: invocation.prompt,
                    schema: schema
                )

                return response.content.jsonString.trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines
                )
            }
        } catch let error as LanguageModelSession.ToolCallError {
            throw error.underlyingError
        } catch let error as AppleFoundationModelError {
            throw error
        } catch {
            throw AppleFoundationModelError.generationFailed(
                String(describing: error)
            )
        }
    }
    #endif
}
