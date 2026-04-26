import Agentic
import AWSConnector
import Primitives
import Foundation

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
                    toolResultText(
                        result.output
                    )
                )
            ],
            status: nil
        )
    }

    static func toolResultText(
        _ output: JSONValue
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys
        ]

        do {
            let data = try encoder.encode(
                output
            )

            if let text = String(
                data: data,
                encoding: .utf8
            ) {
                return text
            }
        } catch {}

        return String(
            describing: output
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
