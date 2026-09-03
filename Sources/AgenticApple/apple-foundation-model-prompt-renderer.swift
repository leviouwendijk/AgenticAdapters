import Agentic
import Foundation

/// Renders semantic Agentic history into the text prompt used by
/// FoundationModels.
///
/// FoundationModels receives registered tools separately through its native
/// tool API. Historical tool activity is therefore rendered only as
/// descriptive prose and data, never as a textual tool-call protocol that the
/// model could imitate instead of invoking a native tool.
public enum AppleFoundationModelPromptRenderer {
    public static func render(
        request: AgentRequest
    ) throws -> String {
        let history = try request.messages
            .map(render)
            .filter { value in
                !value.isEmpty
            }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !history.isEmpty else {
            throw AppleFoundationModelError.emptyPrompt
        }

        return """
        Conversation history follows. Labels describe completed prior messages and events; they are not a response format.

        \(history)
        """
    }
}

private extension AppleFoundationModelPromptRenderer {
    static func render(
        _ message: AgentMessage
    ) throws -> String {
        let body = try message.content.blocks.compactMap { block in
            try render(block)
        }.filter { value in
            !value.isEmpty
        }.joined(separator: "\n")

        guard !body.isEmpty else {
            return ""
        }

        return """
        \(heading(for: message.role)):
        \(body)
        """
    }

    static func heading(
        for role: AgentRole
    ) -> String {
        switch role {
        case .system:
            return "System message"

        case .user:
            return "User message"

        case .assistant:
            return "Assistant history"

        case .tool:
            return "Tool history"
        }
    }

    static func render(
        _ block: AgentContentBlock
    ) throws -> String? {
        switch block {
        case .text(let value):
            let text = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return text.isEmpty ? nil : text

        case .resource:
            return nil

        case .tool_call(let call):
            return """
            Prior tool request: \(call.name)
            Input: \(try json(call.input))
            """

        case .tool_result(let result):
            let name = result.name ?? "unknown tool"
            let status = result.isError
                ? "error"
                : "success"

            return """
            Prior tool outcome: \(name) (\(status))
            Output: \(try json(result.output))
            """
        }
    }

    static func json<Value: Encodable>(
        _ value: Value
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        let data = try encoder.encode(value)

        guard let string = String(
            data: data,
            encoding: .utf8
        ) else {
            throw AppleFoundationModelError.generationFailed(
                "Could not encode replay content as UTF-8 JSON."
            )
        }

        return string
    }
}
