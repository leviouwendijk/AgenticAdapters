import Agentic
import AWSConnector
import Primitives

enum BedrockToolMapper {
    static func map(
        _ tools: [AgentToolDefinition]
    ) -> Bedrock.Converse.ToolConfig? {
        guard !tools.isEmpty else {
            return nil
        }

        return .init(
            tools: tools.map(map)
        )
    }

    static func map(
        _ definition: AgentToolDefinition
    ) -> Bedrock.Converse.Tool {
        .toolSpec(
            .init(
                name: definition.name,
                description: definition.description,
                inputSchema: .init(
                    json: definition.inputSchema ?? defaultSchema
                )
            )
        )
    }

    static func map(
        _ call: AgentToolCall
    ) -> Bedrock.Converse.ToolUse {
        .init(
            toolUseId: call.id,
            name: call.name,
            input: call.input
        )
    }

    static func map(
        _ result: AgentToolResult
    ) -> Bedrock.Converse.ToolResult {
        .init(
            toolUseId: result.toolCallID,
            content: [
                .text(
                    String(
                        describing: result.output
                    )
                )
            ],
            status: nil
        )
    }

    // static func map(
    //     _ result: AgentToolResult
    // ) -> Bedrock.Converse.ToolResult {
    //     .init(
    //         toolUseId: result.toolCallID,
    //         content: [
    //             .json(
    //                 result.output
    //             )
    //         ],
    //         status: nil
    //     )
    // }

    private static let defaultSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
}
