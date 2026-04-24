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
        try validateRequest(
            request
        )

        let prompt = try AppleFoundationModelPromptRenderer.render(
            request: request
        )

        let text = try await generate(
            prompt: prompt
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
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bufferedResponse = try await buffered(
                        request: request
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
                    let text = response.message.content.text

                    if !text.isEmpty {
                        continuation.yield(
                            .messagedelta(
                                .text(text)
                            )
                        )
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

        guard request.tools.isEmpty else {
            throw AppleFoundationModelError.toolsUnsupported(
                request.tools.map(\.name)
            )
        }
    }

    func generate(
        prompt: String
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(
                prompt: prompt
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
        prompt: String
    ) async throws -> String {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break

        case .unavailable(let reason):
            throw AppleFoundationModelError.modelUnavailable(
                String(
                    describing: reason
                )
            )
        }

        do {
            let session = LanguageModelSession(
                model: model
            )
            let response = try await session.respond(
                to: prompt
            )

            return response.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        } catch let error as AppleFoundationModelError {
            throw error
        } catch {
            throw AppleFoundationModelError.generationFailed(
                String(
                    describing: error
                )
            )
        }
    }
    #endif
}
