import Agentic
import AWSConnector

enum BedrockRequestMapper {
    static func model(
        _ request: AgentRequest,
        default defaultModel: String
    ) -> String {
        let requested = request.model?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let requested,
              !requested.isEmpty
        else {
            return defaultModel
        }

        return requested
    }

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
            )
        )
    }
}
