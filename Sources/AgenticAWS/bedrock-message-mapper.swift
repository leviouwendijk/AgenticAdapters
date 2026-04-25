import Agentic
import AWSConnector

enum BedrockMessageMapper {
    static func map(
        _ messages: [AgentMessage]
    ) throws -> (
        system: [Bedrock.Converse.SystemBlock],
        messages: [Bedrock.Converse.Message]
    ) {
        var system: [Bedrock.Converse.SystemBlock] = []
        var mapped: [Bedrock.Converse.Message] = []

        for message in messages {
            switch message.role {
            case .system:
                system.append(
                    contentsOf: try systemBlocks(
                        message
                    )
                )

            case .user:
                mapped.append(
                    try messageBlock(
                        message,
                        role: .user
                    )
                )

            case .assistant:
                mapped.append(
                    try messageBlock(
                        message,
                        role: .assistant
                    )
                )

            case .tool:
                mapped.append(
                    try toolMessage(
                        message
                    )
                )
            }
        }

        return (
            system: system,
            messages: mapped
        )
    }
}

private extension BedrockMessageMapper {
    static func systemBlocks(
        _ message: AgentMessage
    ) throws -> [Bedrock.Converse.SystemBlock] {
        let blocks = try message.content.blocks.map { block in
            guard case .text(let text) = block else {
                throw BedrockAdapterError.unsupportedContent(
                    message.role
                )
            }

            return Bedrock.Converse.SystemBlock(
                text: text
            )
        }

        guard !blocks.isEmpty else {
            throw BedrockAdapterError.emptyContent(
                message.role
            )
        }

        return blocks
    }

    static func messageBlock(
        _ message: AgentMessage,
        role: Bedrock.Converse.Role
    ) throws -> Bedrock.Converse.Message {
        let content = try message.content.blocks.map { block in
            try contentBlock(
                block,
                role: message.role
            )
        }

        guard !content.isEmpty else {
            throw BedrockAdapterError.emptyContent(
                message.role
            )
        }

        return .init(
            role: role,
            content: content
        )
    }

    static func toolMessage(
        _ message: AgentMessage
    ) throws -> Bedrock.Converse.Message {
        let content = try message.content.blocks.map { block in
            guard case .tool_result(let result) = block else {
                throw BedrockAdapterError.unsupportedContent(
                    message.role
                )
            }

            return Bedrock.Converse.ContentBlock.toolResult(
                BedrockToolMapper.map(
                    result
                )
            )
        }

        guard !content.isEmpty else {
            throw BedrockAdapterError.emptyContent(
                message.role
            )
        }

        return .init(
            role: .user,
            content: content
        )
    }

    static func contentBlock(
        _ block: AgentContentBlock,
        role: AgentRole
    ) throws -> Bedrock.Converse.ContentBlock {
        switch block {
        case .text(let text):
            return .text(text)

        case .tool_call(let call):
            guard role == .assistant else {
                throw BedrockAdapterError.unsupportedContent(
                    role
                )
            }

            return .toolUse(
                BedrockToolMapper.map(
                    call
                )
            )

        case .tool_result(let result):
            guard role == .user else {
                throw BedrockAdapterError.unsupportedContent(
                    role
                )
            }

            return .toolResult(
                BedrockToolMapper.map(
                    result
                )
            )
        }
    }
}
