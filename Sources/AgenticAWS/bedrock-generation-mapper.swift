import Agentic
import AWSConnector

enum BedrockGenerationMapper {
    static func map(
        _ config: AgentGenerationConfiguration
    ) -> Bedrock.Converse.Inference? {
        guard config.maxOutputTokens != nil
            || config.temperature != nil
            || config.topP != nil
            || !config.stopSequences.isEmpty
        else {
            return nil
        }

        return .init(
            maxTokens: config.maxOutputTokens,
            temperature: config.temperature,
            topP: config.topP,
            stopSequences: config.stopSequences.isEmpty
                ? nil
                : config.stopSequences
        )
    }
}
