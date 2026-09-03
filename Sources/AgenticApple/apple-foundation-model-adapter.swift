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
        request: AgentRequest
    ) async throws -> AgentResponse {
        try await buffered(
            request: request,
            context: .default
        )
    }

    public func buffered(
        request: AgentRequest,
        context: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        try validateRequest(
            request
        )

        let text = try await generate(
            request: request,
            context: context
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
                "delivery": "buffered"
            ]
        )
    }

    public func stream(
        request: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        stream(
            request: request,
            context: .default
        )
    }

    public func stream(
        request: AgentRequest,
        context: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bufferedResponse = try await buffered(
                        request: request,
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
    func validateRequest(
        _ request: AgentRequest
    ) throws {
        if let model = request.model?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ),
           !model.isEmpty,
           model != "default",
           model != "system",
           model != "system.default" {
            throw AppleFoundationModelError.namedModelUnsupported(
                model
            )
        }

        let resources = request.messages.flatMap {
            $0.content.resources
        }

        guard resources.isEmpty else {
            throw AppleFoundationModelError.resourcesUnsupported(
                resources.map(\.id)
            )
        }
    }

    func generate(
        request: AgentRequest,
        context: AgentModelInvocationContext
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(
                request: request,
                resolver: context.toolCallResolver
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
        request: AgentRequest,
        resolver: (any AgentToolCallResolver)?
    ) async throws -> String {
        let model = SystemLanguageModel.default

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
                        request.tools.map(\.name)
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
            let response = try await session.respond(
                to: invocation.prompt
            )

            return response.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
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
