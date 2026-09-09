import Agentic
import AWSConnector

enum BedrockRequestMapper {
    static func map(
        _ request: AgentRequest
    ) throws -> Bedrock.Converse.Request {
        guard !request.messages.isEmpty else {
            throw BedrockAdapterError.emptyMessages
        }

        let mapped = try BedrockMessageMapper.map(
            request.messages
        )

        guard !mapped.messages.isEmpty else {
            throw BedrockAdapterError.emptyMappedMessages
        }

        return .init(
            messages: mapped.messages,
            system: mapped.system.isEmpty ? nil : mapped.system,
            inferenceConfig: BedrockGenerationMapper.map(
                request.generationConfiguration
            ),
            toolConfig: BedrockToolMapper.map(
                request.tools
            ),
            outputConfig: try BedrockResponseFormatMapper.map(
                request.responseFormat
            )
        )
    }
}
