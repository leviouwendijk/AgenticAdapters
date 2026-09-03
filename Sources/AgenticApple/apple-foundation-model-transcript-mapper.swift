import Agentic
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
package struct AppleFoundationModelInvocation: Sendable {
    package let transcript: Transcript
    package let prompt: String

    package init(
        transcript: Transcript,
        prompt: String
    ) {
        self.transcript = transcript
        self.prompt = prompt
    }
}

@available(macOS 26.0, *)
package enum AppleFoundationModelTranscriptMapper {
    package static let toolContinuationPrompt = """
    Continue the current user request using the tool output already recorded in the transcript. Call another tool only when it is needed to complete the request.
    """

    package static func invocation(
        for request: AgentRequest,
        tools: [AppleFoundationModelToolProxy]
    ) throws -> AppleFoundationModelInvocation {
        let systemMessages = request.messages.filter {
            $0.role == .system
        }
        let conversationMessages = request.messages.filter {
            $0.role != .system
        }

        guard let latestMessage = conversationMessages.last else {
            throw AppleFoundationModelError.emptyPrompt
        }

        let prompt: String
        let historyMessages: [AgentMessage]

        switch latestMessage.role {
        case .user:
            prompt = text(in: latestMessage)
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !prompt.isEmpty else {
                throw AppleFoundationModelError.emptyPrompt
            }

            historyMessages = Array(
                conversationMessages.dropLast()
            )

        case .tool:
            prompt = toolContinuationPrompt
            historyMessages = conversationMessages

        case .assistant:
            prompt = toolContinuationPrompt
            historyMessages = conversationMessages

        case .system:
            throw AppleFoundationModelError.emptyPrompt
        }

        var toolNamesByCallID: [String: String] = [:]

        for message in conversationMessages {
            for block in message.content.blocks {
                guard case .tool_call(let call) = block else {
                    continue
                }

                toolNamesByCallID[call.id] = call.name
            }
        }

        var entries: [Transcript.Entry] = []
        let instructionText = systemMessages
            .map(text)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let toolDefinitions = tools.map { tool in
            Transcript.ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }

        if !instructionText.isEmpty || !toolDefinitions.isEmpty {
            let segments: [Transcript.Segment] = instructionText.isEmpty
                ? []
                : [
                    textSegment(
                        id: "agentic-instructions-text",
                        content: instructionText
                    )
                ]

            entries.append(
                .instructions(
                    Transcript.Instructions(
                        id: systemMessages.first?.id
                            ?? "agentic-instructions",
                        segments: segments,
                        toolDefinitions: toolDefinitions
                    )
                )
            )
        }

        for message in historyMessages {
            switch message.role {
            case .system:
                continue

            case .user:
                let value = text(in: message)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard !value.isEmpty else {
                    continue
                }

                entries.append(
                    .prompt(
                        Transcript.Prompt(
                            id: message.id,
                            segments: [
                                textSegment(
                                    id: "\(message.id)-text",
                                    content: value
                                )
                            ]
                        )
                    )
                )

            case .assistant:
                let value = text(in: message)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                if !value.isEmpty {
                    entries.append(
                        .response(
                            Transcript.Response(
                                id: message.id,
                                assetIDs: [],
                                segments: [
                                    textSegment(
                                        id: "\(message.id)-text",
                                        content: value
                                    )
                                ]
                            )
                        )
                    )
                }

                var calls: [Transcript.ToolCall] = []

                for block in message.content.blocks {
                    guard case .tool_call(let call) = block else {
                        continue
                    }

                    calls.append(
                        Transcript.ToolCall(
                            id: call.id,
                            toolName: call.name,
                            arguments: try GeneratedContent(
                                json: try json(call.input)
                            )
                        )
                    )
                }

                if !calls.isEmpty {
                    entries.append(
                        .toolCalls(
                            Transcript.ToolCalls(
                                id: "\(message.id)-tool-calls",
                                calls
                            )
                        )
                    )
                }

            case .tool:
                for block in message.content.blocks {
                    guard case .tool_result(let result) = block else {
                        continue
                    }

                    guard let toolName = result.name
                        ?? toolNamesByCallID[result.toolCallID]
                    else {
                        throw AppleFoundationModelError.generationFailed(
                            "Cannot map tool result '\(result.toolCallID)' without a tool name"
                        )
                    }

                    let output = try toolOutputText(
                        result
                    )

                    entries.append(
                        .toolOutput(
                            Transcript.ToolOutput(
                                id: result.toolCallID,
                                toolName: toolName,
                                segments: [
                                    textSegment(
                                        id: "\(result.toolCallID)-output-text",
                                        content: output
                                    )
                                ]
                            )
                        )
                    )
                }
            }
        }

        return AppleFoundationModelInvocation(
            transcript: Transcript(
                entries: entries
            ),
            prompt: prompt
        )
    }
}

@available(macOS 26.0, *)
private extension AppleFoundationModelTranscriptMapper {
    static func text(
        in message: AgentMessage
    ) -> String {
        message.content.blocks.compactMap { block in
            guard case .text(let value) = block else {
                return nil
            }

            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return trimmed.isEmpty
                ? nil
                : trimmed
        }.joined(separator: "\n\n")
    }

    static func textSegment(
        id: String,
        content: String
    ) -> Transcript.Segment {
        .text(
            Transcript.TextSegment(
                id: id,
                content: content
            )
        )
    }

    static func toolOutputText(
        _ result: AgentToolResult
    ) throws -> String {
        let output = try json(
            result.output
        )

        guard result.isError else {
            return output
        }

        return "Tool execution failed: \(output)"
    }

    static func json<Value: Encodable>(
        _ value: Value
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        let data = try encoder.encode(
            value
        )

        guard let string = String(
            data: data,
            encoding: .utf8
        ) else {
            throw AppleFoundationModelError.generationFailed(
                "Could not encode semantic history as UTF-8 JSON"
            )
        }

        return string
    }
}
#endif
