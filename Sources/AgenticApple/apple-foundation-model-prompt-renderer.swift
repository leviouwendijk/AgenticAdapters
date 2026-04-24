import Agentic
import Foundation

public enum AppleFoundationModelPromptRenderer {
    public static func render(
        request: AgentRequest
    ) throws -> String {
        let rendered = request.messages
            .map(render)
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "\n\n"
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !rendered.isEmpty else {
            throw AppleFoundationModelError.emptyPrompt
        }

        return rendered
    }
}

private extension AppleFoundationModelPromptRenderer {
    static func render(
        _ message: AgentMessage
    ) -> String {
        let text = message.content.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            return ""
        }

        switch message.role {
        case .system:
            return """
            <system>
            \(text)
            </system>
            """

        case .user:
            return """
            <user>
            \(text)
            </user>
            """

        case .assistant:
            return """
            <assistant>
            \(text)
            </assistant>
            """

        case .tool:
            return """
            <tool>
            \(text)
            </tool>
            """
        }
    }
}
