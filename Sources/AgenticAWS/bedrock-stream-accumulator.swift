import Agentic
import AWSConnector
import Foundation
import Primitives

struct BedrockStreamAccumulator: Sendable {
    private var blocks: [Int: PartialBlock] = [:]
    private var usage: AgentUsage?
    private var response: AgentResponse?
    private let metadata: [String: String]

    init(
        metadata: [String: String]
    ) {
        self.metadata = metadata
    }

    mutating func consume(
        _ event: Bedrock.Converse.StreamEvent
    ) throws -> [AgentStreamEvent] {
        switch event {
        case .messageStart:
            return []

        case .blockStart(let start):
            consume(
                start
            )
            return []

        case .blockDelta(let delta):
            return consume(
                delta
            )

        case .blockStop(let stop):
            return try consume(
                stop
            )

        case .messageStop(let stop):
            return consume(
                stop
            )

        case .metadata(let metadata):
            usage = BedrockUsageMapper.map(
                metadata.usage
            )
            return []

        case .error(let error):
            throw BedrockAdapterError.streamError(
                type: error.type,
                message: error.message
            )

        case .unknown(_, _):
            return []
        }
    }

    func requireCompleted() throws {
        guard response != nil else {
            throw BedrockAdapterError.streamEndedWithoutResponse
        }
    }
}

private extension BedrockStreamAccumulator {
    struct PartialBlock: Sendable, Hashable {
        var text: String = ""
        var toolUseId: String?
        var toolName: String?
        var toolInput: String = ""
        var final: AgentContentBlock?
    }

    mutating func consume(
        _ start: Bedrock.Converse.BlockStart
    ) {
        guard case .toolUse(let toolUse) = start.start else {
            return
        }

        var block = blocks[start.contentBlockIndex] ?? .init()
        block.toolUseId = toolUse.toolUseId
        block.toolName = toolUse.name
        blocks[start.contentBlockIndex] = block
    }

    mutating func consume(
        _ delta: Bedrock.Converse.BlockDelta
    ) -> [AgentStreamEvent] {
        switch delta.delta {
        case .text(let text):
            var block = blocks[delta.contentBlockIndex] ?? .init()
            block.text += text
            blocks[delta.contentBlockIndex] = block

            return [
                .messagedelta(
                    .text(text)
                )
            ]

        case .toolUse(let toolUse):
            var block = blocks[delta.contentBlockIndex] ?? .init()
            block.toolInput += toolUse.input
            blocks[delta.contentBlockIndex] = block

            return []

        case .unknown:
            return []
        }
    }

    mutating func consume(
        _ stop: Bedrock.Converse.BlockStop
    ) throws -> [AgentStreamEvent] {
        guard var block = blocks[stop.contentBlockIndex],
              let id = block.toolUseId,
              let name = block.toolName
        else {
            return []
        }

        let call = AgentToolCall(
            id: id,
            name: name,
            input: try toolInput(
                id: id,
                text: block.toolInput
            )
        )

        block.final = .tool_call(call)
        blocks[stop.contentBlockIndex] = block

        return [
            .toolcall(call)
        ]
    }

    mutating func consume(
        _ stop: Bedrock.Converse.MessageStop
    ) -> [AgentStreamEvent] {
        let response = AgentResponse(
            message: .init(
                role: .assistant,
                content: .init(
                    blocks: finalBlocks()
                )
            ),
            stopReason: BedrockStopReasonMapper.map(
                stop.stopReason
            ),
            usage: usage,
            metadata: responseMetadata(
                stop
            )
        )

        self.response = response

        return [
            .completed(response)
        ]
    }

    func finalBlocks() -> [AgentContentBlock] {
        blocks.keys.sorted().compactMap { index in
            guard let block = blocks[index] else {
                return nil
            }

            if let final = block.final {
                return final
            }

            if !block.text.isEmpty {
                return .text(block.text)
            }

            return nil
        }
    }

    func responseMetadata(
        _ stop: Bedrock.Converse.MessageStop
    ) -> [String: String] {
        var values = metadata

        if let reason = stop.stopReason {
            values["bedrock_stop_reason"] = reason
        }

        return values
    }

    func toolInput(
        id: String,
        text: String
    ) throws -> JSONValue {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return .object([:])
        }

        guard let data = trimmed.data(
            using: .utf8
        ) else {
            throw BedrockAdapterError.invalidToolInput(
                id: id,
                input: text
            )
        }

        do {
            return try JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        } catch {
            throw BedrockAdapterError.invalidToolInput(
                id: id,
                input: text
            )
        }
    }
}
