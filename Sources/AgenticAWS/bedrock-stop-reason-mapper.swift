import Agentic

enum BedrockStopReasonMapper {
    static func map(
        _ reason: String?
    ) -> AgentStopReason {
        switch reason {
        case "end_turn":
            return .end_turn

        case "tool_use":
            return .tool_use

        case "max_tokens":
            return .max_tokens

        case "stop_sequence":
            return .stop_sequence

        default:
            return .error
        }
    }
}
