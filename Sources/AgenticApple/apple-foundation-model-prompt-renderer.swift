import Agentic
import Foundation

public enum AppleFoundationModelPromptRenderer {
    public static func render(
        request: AgentRequest
    ) throws -> String {
        let rendered = try request.messages
            .map(render)
            .filter { value in
                !value.isEmpty
            }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rendered.isEmpty else {
            throw AppleFoundationModelError.emptyPrompt
        }

        return rendered
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
        <\(message.role.rawValue)>
        \(body)
        </\(message.role.rawValue)>
        """
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
            <tool-call id="\(attribute(call.id))" name="\(attribute(call.name))">
            \(try json(call.input))
            </tool-call>
            """

        case .tool_result(let result):
            let name = result.name.map(attribute) ?? ""
            return """
            <tool-result id="\(attribute(result.toolCallID))" name="\(name)" error="\(result.isError)">
            \(try json(result.output))
            </tool-result>
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

        guard let string = String(data: data, encoding: .utf8) else {
            throw AppleFoundationModelError.generationFailed(
                "Could not encode replay content as UTF-8 JSON."
            )
        }

        return string
    }

    static func attribute(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
