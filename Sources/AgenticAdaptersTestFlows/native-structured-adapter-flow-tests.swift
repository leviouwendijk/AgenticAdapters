import Agentic
import AgenticAdapters
import AgenticPrograms
import TestFlows

enum NativeStructuredAdapterFlowTests {
    static let all: [TestFlow] = [
        TestFlow(
            "native-structured-adapter-lowering",
            tags: [
                "adapters",
                "inference",
                "structured-output",
            ]
        ) {
            try loweringDiagnostics()
        },
        TestFlow(
            "native-structured-adapter-decoding",
            tags: [
                "adapters",
                "inference",
                "structured-output",
            ]
        ) {
            try decodingDiagnostics()
        },
    ]

    static func loweringDiagnostics() throws -> [TestFlowDiagnostic] {
        let adapter = NativeStructuredAdapter()
        let realization = AgentInferenceRealization(
            strategy: "direct",
            modelSelection: .executor,
            instructions: "Return the normalized value.",
            budget: .singleAttempt,
            demonstrations: [
                AgentInferenceDemonstration(
                    input: try JSONToolBridge.encode(
                        ProbeStructuredInference.Input(
                            value: "example"
                        )
                    ),
                    output: try JSONToolBridge.encode(
                        "EXAMPLE"
                    )
                ),
            ],
            generation: AgentGenerationConfiguration(
                maxOutputTokens: 64,
                temperature: 0
            )
        )

        let adaptation = try adapter.prepare(
            ProbeStructuredInference.self,
            input: ProbeStructuredInference.Input(
                value: "hello"
            ),
            realization: realization
        )

        try Expect.equal(
            adapter.identifier.rawValue,
            "native_structured",
            "native structured adapter identifier"
        )

        try Expect.equal(
            adaptation.request.messages.count,
            4,
            "lowering emits system, demonstration pair, and input messages"
        )

        try Expect.equal(
            adaptation.request.messages[0].role,
            .system,
            "first lowered message is system instructions"
        )

        try Expect.contains(
            adaptation.request.messages[0].content.text,
            ProbeStructuredInference.definition.purpose,
            "system message contains inference purpose"
        )

        try Expect.contains(
            adaptation.request.messages[0].content.text,
            realization.instructions,
            "system message contains realization instructions"
        )

        try Expect.equal(
            adaptation.request.messages[1].role,
            .user,
            "demonstration input is user message"
        )

        try Expect.equal(
            adaptation.request.messages[2].role,
            .assistant,
            "demonstration output is assistant message"
        )

        try Expect.equal(
            adaptation.request.messages[3].content.text,
            "{\"value\":\"hello\"}",
            "typed inference input lowers deterministically to JSON"
        )

        try Expect.equal(
            adaptation.request.generationConfiguration,
            realization.generation,
            "lowering preserves generation configuration"
        )

        switch adaptation.request.responseFormat {
        case .text:
            throw TestFlowAssertionFailure(
                label: "native structured response format",
                message: "adapter lowered inference as text instead of semantic JSON schema"
            )

        case .jsonschema(let schema):
            try Expect.equal(
                schema,
                String.jsonschema,
                "response format uses inference output schema"
            )
        }

        try Expect.contains(
            Array(
                adaptation.requirements.capabilities
            ),
            .structured_output,
            "adapter requires native structured output"
        )

        try Expect.equal(
            adaptation.request.metadata["inference.identifier"],
            ProbeStructuredInference.definition.identifier.rawValue,
            "request records inference identity"
        )

        return [
            .field(
                "adapter",
                adapter.identifier.rawValue
            ),
            .field(
                "messages",
                "\(adaptation.request.messages.count)"
            ),
            .field(
                "response-format",
                "jsonschema"
            ),
        ]
    }

    static func decodingDiagnostics() throws -> [TestFlowDiagnostic] {
        let adapter = NativeStructuredAdapter()
        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                content: AgentContent(
                    text: "\"HELLO\""
                )
            ),
            stopReason: .end_turn
        )

        let output = try adapter.decode(
            ProbeStructuredInference.self,
            response: response
        )

        try Expect.equal(
            output,
            "HELLO",
            "structured response restores typed inference output"
        )

        try Expect.throwsError(
            "invalid structured response throws"
        ) {
            _ = try adapter.decode(
                ProbeStructuredInference.self,
                response: AgentResponse(
                    message: AgentMessage(
                        role: .assistant,
                        content: AgentContent(
                            text: "not-json"
                        )
                    ),
                    stopReason: .end_turn
                )
            )
        }

        try Expect.throwsError(
            "empty structured response throws"
        ) {
            _ = try adapter.decode(
                ProbeStructuredInference.self,
                response: AgentResponse(
                    message: AgentMessage(
                        role: .assistant,
                        content: AgentContent()
                    ),
                    stopReason: .end_turn
                )
            )
        }

        return [
            .field(
                "decoded",
                output
            ),
        ]
    }
}

private struct ProbeStructuredInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "probe.structured",
        purpose: "Normalize the supplied value."
    )
}
