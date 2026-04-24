import Agentic
import AgenticApple
import Foundation
import Primitives
import TestFlows

extension AgenticAdaptersFlowTesting {
    static func runApplePromptRendering() async throws -> [TestFlowDiagnostic] {
        let request = AgentRequest(
            messages: [
                .init(
                    role: .system,
                    text: "Answer briefly."
                ),
                .init(
                    role: .user,
                    text: "Say hello."
                ),
            ]
        )

        let rendered = try AppleFoundationModelPromptRenderer.render(
            request: request
        )

        try Expect.contains(
            rendered,
            "<system>",
            "rendered includes system section"
        )
        try Expect.contains(
            rendered,
            "Answer briefly.",
            "rendered includes system content"
        )
        try Expect.contains(
            rendered,
            "<user>",
            "rendered includes user section"
        )
        try Expect.contains(
            rendered,
            "Say hello.",
            "rendered includes user content"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            .section(
                "rendered",
                rendered.components(
                    separatedBy: "\n"
                )
            ),
            .field(
                "characters",
                String(
                    rendered.count
                )
            )
        ]
    }

    static func runAppleToolsUnsupported() async throws -> [TestFlowDiagnostic] {
        let adapter = AppleFoundationModelAdapter()
        let request = AgentRequest(
            messages: [
                .init(
                    role: .user,
                    text: "Use a tool."
                )
            ],
            tools: [
                .init(
                    name: "example_tool",
                    description: "A placeholder test tool.",
                    inputSchema: .object([:])
                )
            ]
        )

        do {
            _ = try await adapter.respond(
                request: request
            )
        } catch let error as AppleFoundationModelError {
            switch error {
            case .toolsUnsupported(let tools):
                try Expect.equal(
                    tools,
                    ["example_tool"],
                    "unsupported tool names"
                )

                return [
                    AdapterFlowDiagnostics.input(
                        request
                    ),
                    .field(
                        "tools",
                        tools.joined(
                            separator: ", "
                        )
                    ),
                    .field(
                        "output",
                        String(
                            describing: error
                        )
                    )
                ]

            default:
                throw TestFlowAssertionFailure(
                    label: "tools unsupported",
                    message: "unexpected AppleFoundationModelError",
                    actual: String(
                        describing: error
                    ),
                    expected: "toolsUnsupported"
                )
            }
        } catch {
            throw TestFlowAssertionFailure(
                label: "tools unsupported",
                message: "unexpected error type",
                actual: String(
                    describing: error
                ),
                expected: "AppleFoundationModelError"
            )
        }

        throw TestFlowAssertionFailure(
            label: "tools unsupported",
            message: "request completed unexpectedly",
            actual: "completed",
            expected: "throw"
        )
    }

    static func runAdapterStreamSupported() async throws -> [TestFlowDiagnostic] {
        let request = AgentRequest(
            model: "scripted",
            messages: [
                .init(
                    role: .user,
                    text: "Stream a tiny response."
                )
            ]
        )
        let response = AgentResponse(
            message: .init(
                role: .assistant,
                text: "stream ok"
            ),
            stopReason: .end_turn,
            metadata: [
                "source": "adapterflowtest"
            ]
        )
        let adapter = AdapterFlowScriptedModelAdapter(
            streamBatches: [
                [
                    .messagedelta(
                        .text("stream ")
                    ),
                    .messagedelta(
                        .text("ok")
                    ),
                    .completed(response),
                ]
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

        let text = streamText(
            from: events
        )

        try Expect.equal(
            text,
            "stream ok",
            "stream text"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            AdapterFlowDiagnostics.stream(
                events
            ),
            AdapterFlowDiagnostics.output(
                response
            )
        ]
    }

    static func runAdapterToolLoop() async throws -> [TestFlowDiagnostic] {
        let toolCall = AgentToolCall(
            id: "adapter-flow-tool-call-1",
            name: AdapterFlowEchoTool.identifier.rawValue,
            input: try JSONToolBridge.encode(
                AdapterFlowEchoToolInput(
                    text: "tool payload"
                )
            )
        )
        let request = AgentRequest(
            model: "scripted",
            messages: [
                .init(
                    role: .user,
                    text: "Use the echo tool, then answer with 'tool use ok'."
                )
            ]
        )
        let firstResponse = AgentResponse(
            message: .init(
                role: .assistant,
                content: .init(
                    blocks: [
                        .text("need tool "),
                        .tool_call(toolCall)
                    ]
                )
            ),
            stopReason: .tool_use,
            metadata: [
                "source": "adapterflowtest"
            ]
        )
        let finalResponse = AgentResponse(
            message: .init(
                role: .assistant,
                text: "tool use ok"
            ),
            stopReason: .end_turn,
            metadata: [
                "source": "adapterflowtest"
            ]
        )
        let adapter = AdapterFlowScriptedModelAdapter(
            streamBatches: [
                [
                    .messagedelta(
                        .text("need tool ")
                    ),
                    .toolcall(toolCall),
                    .completed(firstResponse),
                ],
                [
                    .completed(finalResponse)
                ]
            ]
        )
        let runner = AgentRunner(
            adapter: adapter,
            configuration: .init(
                maximumIterations: 2,
                responseDelivery: .stream
            ),
            toolRegistry: .init(
                tools: [
                    AdapterFlowEchoTool()
                ]
            )
        )

        let result = try await runner.run(
            request,
            sessionID: "adapter-flow-tool-loop"
        )

        try Expect.equal(
            result.response?.message.content.text,
            "tool use ok",
            "tool loop final response"
        )

        try Expect.containsOrdered(
            result.events.map(\.kind),
            [
                .model_stream_started,
                .model_stream_tool_call,
                .model_stream_completed,
                .assistant_response,
                .tool_preflight,
                .tool_approved,
                .tool_result,
                .model_stream_started,
                .model_stream_completed,
                .assistant_response
            ],
            "tool loop events"
        )

        let recordedRequests = await adapter.recordedRequests()

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            .field(
                "model_calls",
                String(
                    recordedRequests.count
                )
            ),
            AdapterFlowDiagnostics.events(
                result.events
            ),
            AdapterFlowDiagnostics.output(
                finalResponse
            )
        ]
    }

    static func runAppleLiveQuery() async throws -> [TestFlowDiagnostic] {
        let enabled = ProcessInfo.processInfo.environment["AGENTIC_APPLE_LIVE_TEST"] == "1"

        guard enabled else {
            return [
                .message("skipped: set AGENTIC_APPLE_LIVE_TEST=1 to run the live FoundationModels query")
            ]
        }

        let adapter = AppleFoundationModelAdapter()
        let runner = AgentRunner(
            adapter: adapter
        )
        let request = AgentRequest(
            messages: [
                .init(
                    role: .system,
                    text: "Answer in one short sentence."
                ),
                .init(
                    role: .user,
                    text: "Say hello from AgenticApple."
                ),
            ]
        )

        let result = try await runner.run(
            request,
            sessionID: "agentic-adapters-live-query"
        )

        guard let response = result.response else {
            throw TestFlowAssertionFailure(
                label: "live query",
                message: "run completed without a response",
                actual: String(
                    describing: result
                ),
                expected: "non-nil response"
            )
        }

        let text = response.message.content.text.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        try Expect.notEmpty(
            text,
            "live response text"
        )

        return [
            AdapterFlowDiagnostics.input(
                request
            ),
            AdapterFlowDiagnostics.output(
                response
            )
        ]
    }

    static func runAppleLiveStreamQuery() async throws -> [TestFlowDiagnostic] {
        let enabled = ProcessInfo.processInfo.environment["AGENTIC_APPLE_LIVE_TEST"] == "1"

        guard enabled else {
            return [
                .message("skipped: set AGENTIC_APPLE_LIVE_TEST=1 to run the live FoundationModels stream query")
            ]
        }

        let adapter = AppleFoundationModelAdapter()
        let request = AgentRequest(
            messages: [
                .init(
                    role: .system,
                    text: "Answer in one short sentence."
                ),
                .init(
                    role: .user,
                    text: "Say hello from the AgenticApple stream."
                ),
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

        let text = streamText(
            from: events
        )

        try Expect.notEmpty(
            text,
            "live stream text"
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
}

private func streamText(
    from events: [AgentStreamEvent]
) -> String {
    events.compactMap { event in
        switch event {
        case .messagedelta(.text(let value)):
            return value

        default:
            return nil
        }
    }.joined()
}
