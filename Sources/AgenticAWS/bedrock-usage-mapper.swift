import Agentic
import AWSConnector

enum BedrockUsageMapper {
    static func map(
        _ usage: Bedrock.Converse.Usage?
    ) -> AgentUsage? {
        guard let usage else {
            return nil
        }

        return .init(
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            totalTokens: usage.totalTokens
        )
    }
}
