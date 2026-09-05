import Agentic
import AgenticAWS
import AWSConnector
import Primitives
import TestFlows

extension AgenticAdaptersFlowTesting {
    static func runBedrockBufferedStreamCompletion() async throws -> [TestFlowDiagnostic] {
        let runtime = BedrockFlowRuntime(
            responses: [
                BedrockFlowFixture.response(
                    text: "bedrock ok",
                    usage: .init(
                        inputTokens: 3,
                        outputTokens: 2,
                        totalTokens: 5
                    )
                )
            ]
        )
        let adapter = BedrockModelAdapter(
            runtime: runtime,
            defaultModelIdentifier: "default-model"
        )
        let request = AgentRequest(
            model: "override-model",
            messages: [
                .init(
                    role: .system,
                    text: "Answer briefly."
                ),
                .init(
                    role: .user,
                    text: "Say hello."
                )
            ],
            generationConfiguration: .init(
                maxOutputTokens: 24,
                temperature: 0.0
            )
        )

        let response = try await adapter.respond(
            request: request
        )
        let call = try await runtime.onlyCall()

        try Expect.equal(
            call.delivery,
            AgentModelResponseDelivery.buffered,
            "buffered response does not use the stream path"
        )
        try Expect.equal(
            call.model,
            "override-model",
            "selected model"
        )
        try Expect.equal(
            call.request.system,
            [
                .init(
                    text: "Answer briefly."
                )
            ],
            "system blocks"
        )
        try Expect.equal(
            call.request.messages,
            [
                .init(
                    role: .user,
                    content: [
                        .text("Say hello.")
                    ]
                )
            ],
            "messages"
        )
        try Expect.equal(
            call.request.inferenceConfig,
            .init(
                maxTokens: 24,
                temperature: 0.0
            ),
            "inference config"
        )
        try Expect.equal(
            response.message.content.text,
            "bedrock ok",
            "response text"
        )
        try Expect.equal(
            response.usage,
            .init(
                inputTokens: 3,
                outputTokens: 2,
                totalTokens: 5
            ),
            "usage"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            AdapterFlowDiagnostics.output(
                response
            ),
            .field(
                "model",
                call.model
            )
        ]
    }

    static func runBedrockToolUseStream() async throws -> [TestFlowDiagnostic] {
        let runtime = BedrockFlowRuntime(
            batches: [
                BedrockFlowFixture.toolUse(
                    id: "tool-1",
                    name: "adapter_scratchpad_put",
                    input: [
                        "{\"text\":",
                        "\"hello\"}"
                    ]
                )
            ]
        )
        let adapter = BedrockModelAdapter(
            runtime: runtime,
            defaultModelIdentifier: "default-model"
        )
        let request = AgentRequest(
            messages: [
                .init(
                    role: .user,
                    text: "Store a note."
                )
            ]
        )
        var events: [AgentStreamEvent] = []

        for try await event in adapter.respond(
            request: request,
            delivery: .stream
        ) {
            events.append(
                event
            )
        }

        let call = try onlyToolCall(
            events
        )
        let response = try completed(
            events
        )

        try Expect.equal(
            call.id,
            "tool-1",
            "tool id"
        )
        try Expect.equal(
            call.name,
            "adapter_scratchpad_put",
            "tool name"
        )
        try Expect.contains(
            String(
                describing: call.input
            ),
            "hello",
            "tool input"
        )
        try Expect.equal(
            response.stopReason,
            .tool_use,
            "stop reason"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            AdapterFlowDiagnostics.stream(
                events
            )
        ]
    }

    static func runBedrockToolResultMapping() async throws -> [TestFlowDiagnostic] {
        let runtime = BedrockFlowRuntime(
            responses: [
                BedrockFlowFixture.response(
                    text: "done"
                )
            ]
        )
        let adapter = BedrockModelAdapter(
            runtime: runtime,
            defaultModelIdentifier: "default-model"
        )
        let request = AgentRequest(
            messages: [
                .init(
                    role: .tool,
                    content: .init(
                        blocks: [
                            .tool_result(
                                .init(
                                    toolCallID: "tool-1",
                                    name: "adapter_scratchpad_put",
                                    output: .object([
                                        "ok": .bool(true)
                                    ])
                                )
                            ),
                            .tool_result(
                                .init(
                                    toolCallID: "tool-2",
                                    name: "fixture_tool",
                                    output: .object([
                                        "kind": .string("tool_error"),
                                        "message": .string("Edit line payload contains newline characters and is not a single logical line.")
                                    ]),
                                    isError: true
                                )
                            )
                        ]
                    )
                )
            ]
        )

        _ = try await adapter.respond(
            request: request
        )

        let call = try await runtime.onlyCall()
        let message = try Expect.notNil(
            call.request.messages.first,
            "mapped message"
        )

        let results = message.content.compactMap { block -> Bedrock.Converse.ToolResult? in
            guard case .toolResult(let result) = block else {
                return nil
            }

            return result
        }

        try Expect.equal(
            message.role,
            .user,
            "tool result role"
        )
        try Expect.equal(
            results.count,
            2,
            "tool result count"
        )

        let successResult = results[0]
        let errorResult = results[1]

        try Expect.equal(
            successResult.toolUseId,
            "tool-1",
            "success tool use id"
        )
        try Expect.equal(
            successResult.status,
            .success,
            "success tool result status"
        )
        try Expect.equal(
            errorResult.toolUseId,
            "tool-2",
            "error tool use id"
        )
        try Expect.equal(
            errorResult.status,
            .error,
            "error tool result status"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            .field(
                "successToolUseId",
                successResult.toolUseId
            ),
            .field(
                "errorToolUseId",
                errorResult.toolUseId
            )
        ]
    }
}

private struct BedrockFlowCall: Sendable {
    let request: Bedrock.Converse.Request
    let model: String
    let delivery: AgentModelResponseDelivery
}

private struct BedrockFlowRuntime: BedrockModelRuntime {
    let state: BedrockFlowRuntimeState

    init(
        responses: [Bedrock.Converse.Response] = [],
        batches: [[Bedrock.Converse.StreamEvent]] = []
    ) {
        self.state = .init(
            responses: responses,
            batches: batches
        )
    }

    func respond(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) async throws -> Bedrock.Converse.Response {
        try await state.nextResponse(
            request: request,
            model: modelIdentifier
        )
    }

    func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let events = try await state.next(
                        request: request,
                        model: modelIdentifier
                    )

                    for event in events {
                        continuation.yield(
                            event
                        )
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func onlyCall() async throws -> BedrockFlowCall {
        let calls = await state.calls()

        guard calls.count == 1,
              let call = calls.first
        else {
            throw TestFlowAssertionFailure(
                label: "Bedrock calls",
                message: "expected exactly one call",
                actual: String(
                    calls.count
                ),
                expected: "1"
            )
        }

        return call
    }
}

private actor BedrockFlowRuntimeState {
    private var responses: [Bedrock.Converse.Response]
    private var batches: [[Bedrock.Converse.StreamEvent]]
    private var recorded: [BedrockFlowCall] = []

    init(
        responses: [Bedrock.Converse.Response],
        batches: [[Bedrock.Converse.StreamEvent]]
    ) {
        self.responses = responses
        self.batches = batches
    }

    func nextResponse(
        request: Bedrock.Converse.Request,
        model: String
    ) throws -> Bedrock.Converse.Response {
        recorded.append(
            .init(
                request: request,
                model: model,
                delivery: .buffered
            )
        )

        guard !responses.isEmpty else {
            throw TestFlowAssertionFailure(
                label: "Bedrock fixture",
                message: "missing buffered response"
            )
        }

        return responses.removeFirst()
    }

    func next(
        request: Bedrock.Converse.Request,
        model: String
    ) throws -> [Bedrock.Converse.StreamEvent] {
        recorded.append(
            .init(
                request: request,
                model: model,
                delivery: .stream
            )
        )

        guard !batches.isEmpty else {
            throw TestFlowAssertionFailure(
                label: "Bedrock fixture",
                message: "missing event batch"
            )
        }

        return batches.removeFirst()
    }

    func calls() -> [BedrockFlowCall] {
        recorded
    }
}

private enum BedrockFlowFixture {
    static func response(
        text: String,
        usage: Bedrock.Converse.Usage? = nil
    ) -> Bedrock.Converse.Response {
        .init(
            output: .message(
                .init(
                    role: .assistant,
                    content: [
                        .text(text),
                    ]
                )
            ),
            stopReason: "end_turn",
            usage: usage
        )
    }

    static func text(
        _ parts: [String],
        usage: Bedrock.Converse.Usage? = nil
    ) -> [Bedrock.Converse.StreamEvent] {
        var events: [Bedrock.Converse.StreamEvent] = [
            .messageStart(
                .init(
                    role: .assistant
                )
            )
        ]

        for part in parts {
            events.append(
                .blockDelta(
                    .init(
                        contentBlockIndex: 0,
                        delta: .text(part)
                    )
                )
            )
        }

        if let usage {
            events.append(
                .metadata(
                    .init(
                        usage: usage
                    )
                )
            )
        }

        events.append(
            .messageStop(
                .init(
                    stopReason: "end_turn"
                )
            )
        )

        return events
    }

    static func toolUse(
        id: String,
        name: String,
        input: [String]
    ) -> [Bedrock.Converse.StreamEvent] {
        var events: [Bedrock.Converse.StreamEvent] = [
            .messageStart(
                .init(
                    role: .assistant
                )
            ),
            .blockStart(
                .init(
                    contentBlockIndex: 0,
                    start: .toolUse(
                        .init(
                            toolUseId: id,
                            name: name
                        )
                    )
                )
            )
        ]

        for fragment in input {
            events.append(
                .blockDelta(
                    .init(
                        contentBlockIndex: 0,
                        delta: .toolUse(
                            .init(
                                input: fragment
                            )
                        )
                    )
                )
            )
        }

        events.append(
            .blockStop(
                .init(
                    contentBlockIndex: 0
                )
            )
        )
        events.append(
            .messageStop(
                .init(
                    stopReason: "tool_use"
                )
            )
        )

        return events
    }
}

private func onlyToolCall(
    _ events: [AgentStreamEvent]
) throws -> AgentToolCall {
    let calls = events.compactMap { event -> AgentToolCall? in
        guard case .toolcall(let call) = event else {
            return nil
        }

        return call
    }

    guard calls.count == 1,
          let call = calls.first
    else {
        throw TestFlowAssertionFailure(
            label: "tool call",
            message: "expected exactly one tool call",
            actual: String(
                calls.count
            ),
            expected: "1"
        )
    }

    return call
}

private func completed(
    _ events: [AgentStreamEvent]
) throws -> AgentResponse {
    let responses = events.compactMap { event -> AgentResponse? in
        guard case .completed(let response) = event else {
            return nil
        }

        return response
    }

    guard responses.count == 1,
          let response = responses.first
    else {
        throw TestFlowAssertionFailure(
            label: "completed response",
            message: "expected exactly one completed response",
            actual: String(
                responses.count
            ),
            expected: "1"
        )
    }

    return response
}
