import Agentic
import AgenticApple
import Foundation
import Primitives
import TestFlows

#if canImport(FoundationModels)
import FoundationModels
#endif

extension AgenticAdaptersFlowTesting {
    static func runApplePromptRendering() async throws -> [TestFlowDiagnostic] {
        let request = AgentRequest(
            messages: [
                .init(role: .system, text: "Answer briefly."),
                .init(role: .user, text: "Say hello."),
            ]
        )
        let rendered = try AppleFoundationModelPromptRenderer.render(
            request: request
        )

        try Expect.contains(
            rendered,
            "System message:",
            "rendered labels system history descriptively"
        )
        try Expect.contains(
            rendered,
            "Answer briefly.",
            "rendered includes system content"
        )
        try Expect.contains(
            rendered,
            "User message:",
            "rendered labels user history descriptively"
        )
        try Expect.contains(
            rendered,
            "Say hello.",
            "rendered includes user content"
        )
        try Expect.equal(
            rendered.contains("<system>"),
            false,
            "rendered does not teach a system pseudo-tag"
        )
        try Expect.equal(
            rendered.contains("<user>"),
            false,
            "rendered does not teach a user pseudo-tag"
        )

        return [
            AdapterFlowDiagnostics.input(request),
            .section(
                "rendered",
                rendered.components(separatedBy: "\n")
            ),
            .field("characters", String(rendered.count)),
        ]
    }

    static func runAppleToolBridge() async throws -> [TestFlowDiagnostic] {
        let definition = AgentToolDefinition(
            name: "read_file",
            description: "Read a UTF-8 file in the authorized workspace.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "path": .object([
                        "type": .string("string"),
                        "description": .string("Workspace-relative file path.")
                    ]),
                    "recursive": .object([
                        "type": .string("boolean")
                    ])
                ]),
                "required": .array([
                    .string("path")
                ])
            ])
        )
        let priorCall = AgentToolCall(
            id: "apple-tool-call",
            name: "read_file",
            input: .object([
                "path": .string("Sources/example.swift")
            ])
        )
        let priorResult = AgentToolResult(
            toolCallID: priorCall.id,
            name: priorCall.name,
            output: .object([
                "text": .string("let value = 42")
            ]),
            isError: false
        )
        let request = AgentRequest(
            messages: [
                .init(role: .user, text: "Read the example file."),
                .init(
                    role: .assistant,
                    content: .init(blocks: [.tool_call(priorCall)])
                ),
                .init(
                    role: .tool,
                    content: .init(blocks: [.tool_result(priorResult)])
                ),
            ],
            tools: [definition]
        )
        let rendered = try AppleFoundationModelPromptRenderer.render(
            request: request
        )

        try Expect.contains(
            rendered,
            "Prior tool request: read_file",
            "prompt preserves prior tool request descriptively"
        )
        try Expect.contains(
            rendered,
            "\"path\":\"Sources/example.swift\"",
            "prompt preserves exact prior tool input"
        )
        try Expect.contains(
            rendered,
            "Prior tool outcome: read_file (success)",
            "prompt preserves prior tool result descriptively"
        )
        try Expect.contains(
            rendered,
            "let value = 42",
            "prompt preserves prior tool output"
        )
        try Expect.equal(
            rendered.contains("<tool-call"),
            false,
            "prompt does not teach a textual tool-call protocol"
        )
        try Expect.equal(
            rendered.contains("<tool-result"),
            false,
            "prompt does not teach a textual tool-result protocol"
        )
        try Expect.equal(
            rendered.contains("<assistant>"),
            false,
            "prompt does not teach an assistant pseudo-tag"
        )
        try Expect.equal(
            rendered.contains("<tool>"),
            false,
            "prompt does not teach a tool-role pseudo-tag"
        )

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let tools = try AppleFoundationModelToolBridge.tools(
                for: [definition]
            )

            try Expect.equal(
                tools.count,
                1,
                "lowered Apple tool count"
            )

            let initialInvocation = try AppleFoundationModelTranscriptMapper.invocation(
                for: AgentRequest(
                    messages: [
                        .init(
                            role: .system,
                            text: "Answer briefly."
                        ),
                        .init(
                            role: .user,
                            text: "Say hello."
                        ),
                    ],
                    tools: [definition]
                ),
                tools: tools
            )

            try Expect.equal(
                initialInvocation.prompt,
                "Say hello.",
                "latest user message becomes the native Apple prompt"
            )

            let initialTranscriptJSON = String(
                decoding: try JSONEncoder().encode(
                    initialInvocation.transcript
                ),
                as: UTF8.self
            )

            try Expect.equal(
                initialTranscriptJSON.contains("Say hello."),
                false,
                "latest user prompt is not duplicated into native history"
            )
            try Expect.contains(
                initialTranscriptJSON,
                "Answer briefly.",
                "native history preserves system instructions"
            )
            try Expect.contains(
                initialTranscriptJSON,
                "read_file",
                "native history preserves current tool definitions"
            )

            let continuationInvocation = try AppleFoundationModelTranscriptMapper.invocation(
                for: request,
                tools: tools
            )

            try Expect.equal(
                continuationInvocation.prompt,
                AppleFoundationModelTranscriptMapper.toolContinuationPrompt,
                "tool output advances through a bounded continuation prompt"
            )

            let continuationTranscriptJSON = String(
                decoding: try JSONEncoder().encode(
                    continuationInvocation.transcript
                ),
                as: UTF8.self
            )

            try Expect.contains(
                continuationTranscriptJSON,
                "Read the example file.",
                "native history preserves the original user request"
            )
            try Expect.contains(
                continuationTranscriptJSON,
                "read_file",
                "native history preserves semantic tool identity"
            )
            try Expect.contains(
                continuationTranscriptJSON,
                "Sources\\/example.swift",
                "native history preserves semantic tool arguments"
            )
            try Expect.contains(
                continuationTranscriptJSON,
                "let value = 42",
                "native history preserves semantic tool output"
            )

            guard let tool = tools.first else {
                throw TestFlowAssertionFailure(
                    label: "Apple tool bridge",
                    message: "lowered tool missing",
                    actual: "0",
                    expected: "1"
                )
            }

            do {
                _ = try await tool.call(
                    arguments: GeneratedContent(
                        json: "{\"path\":\"Sources/example.swift\"}"
                    )
                )
            } catch let requested as AppleFoundationModelToolCallRequested {
                try Expect.equal(
                    requested.call.name,
                    "read_file",
                    "intercepted Agentic tool name"
                )
                try Expect.equal(
                    requested.call.input,
                    .object([
                        "path": .string("Sources/example.swift")
                    ]),
                    "intercepted Agentic tool input"
                )

                return [
                    AdapterFlowDiagnostics.input(request),
                    .field("tool", requested.call.name),
                    .field("stop-boundary", "semantic tool request"),
                    .section(
                        "rendered",
                        rendered.components(separatedBy: "\n")
                    ),
                ]
            } catch {
                throw TestFlowAssertionFailure(
                    label: "Apple tool bridge",
                    message: "unexpected interception error",
                    actual: String(describing: error),
                    expected: "AppleFoundationModelToolCallRequested"
                )
            }

            throw TestFlowAssertionFailure(
                label: "Apple tool bridge",
                message: "proxy executed without yielding to AgentRunner",
                actual: "returned",
                expected: "semantic tool request"
            )
        }
        #endif

        return [
            AdapterFlowDiagnostics.input(request),
            .field("tool", definition.name),
            .field("native-bridge", "platform unavailable"),
            .section(
                "rendered",
                rendered.components(separatedBy: "\n")
            ),
        ]
    }
}
