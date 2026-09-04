import Agentic

struct OllamaStreamAccumulator: Sendable {
    private var text = ""
    private var calls: [AgentToolCall] = []
    private var emittedCallIDs: Set<String> = []
    private var response: AgentResponse?
    private let baseMetadata: [String: String]

    init(metadata: [String: String]) {
        self.baseMetadata = metadata
    }

    mutating func consume(_ chunk: OllamaChatChunk) -> [AgentStreamEvent] {
        var events: [AgentStreamEvent] = []

        if let delta = chunk.message?.content, !delta.isEmpty {
            text += delta
            events.append(.messagedelta(.text(delta)))
        }

        if let providerCalls = chunk.message?.toolCalls {
            for providerCall in providerCalls where !emittedCallIDs.contains(providerCall.id) {
                let call = AgentToolCall(
                    id: providerCall.id,
                    name: providerCall.function.name,
                    input: providerCall.function.arguments
                )
                emittedCallIDs.insert(providerCall.id)
                calls.append(call)
                events.append(.toolcall(call))
            }
        }

        guard chunk.done else {
            return events
        }

        var blocks: [AgentContentBlock] = []
        if !text.isEmpty {
            blocks.append(.text(text))
        }
        blocks.append(contentsOf: calls.map { .tool_call($0) })

        var metadata = baseMetadata
        if let model = chunk.model { metadata["model"] = model }
        if let reason = chunk.doneReason { metadata["done_reason"] = reason }
        if let value = chunk.totalDuration { metadata["total_duration_ns"] = String(value) }
        if let value = chunk.loadDuration { metadata["load_duration_ns"] = String(value) }
        if let value = chunk.promptEvalDuration { metadata["prompt_eval_duration_ns"] = String(value) }
        if let value = chunk.evalDuration { metadata["eval_duration_ns"] = String(value) }

        let inputTokens = chunk.promptEvalCount
        let outputTokens = chunk.evalCount
        let usage: AgentUsage? = inputTokens == nil && outputTokens == nil
            ? nil
            : .init(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                totalTokens: (inputTokens ?? 0) + (outputTokens ?? 0)
            )

        let completed = AgentResponse(
            message: .init(
                role: .assistant,
                content: .init(blocks: blocks)
            ),
            stopReason: calls.isEmpty ? stopReason(chunk.doneReason) : .tool_use,
            usage: usage,
            metadata: metadata
        )
        response = completed
        events.append(.completed(completed))
        return events
    }

    func requireCompleted() throws {
        guard response != nil else {
            throw OllamaAdapterError.streamEndedWithoutResponse
        }
    }

    private func stopReason(_ reason: String?) -> AgentStopReason {
        switch reason {
        case "stop", nil:
            return .end_turn
        case "length":
            return .max_tokens
        default:
            return .error
        }
    }
}
