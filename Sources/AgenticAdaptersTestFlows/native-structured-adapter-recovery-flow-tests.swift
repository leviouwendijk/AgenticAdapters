import Agentic
import AgenticAdapters
import AgenticInference
import AgenticRecovery
import Foundation
import TestFlows

private struct NativeStructuredRecoveryFixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "fixture.native_structured_recovery",
        purpose: "Prove concrete NativeStructuredAdapter recovery."
    )
}

private enum NativeStructuredRecoveryFixtureError:
    Error,
    Sendable,
    LocalizedError
{
    case streamingUnsupported

    var errorDescription: String? {
        switch self {
        case .streamingUnsupported:
            "native structured recovery fixture does not stream"
        }
    }
}

private actor NativeStructuredRecoveryFixtureState {
    private var count = 0
    private var repairRequestSeen = false
    private var previousMalformedResponseSeen = false

    func record(
        invocation: AgentModelInvocation
    ) -> Int {
        let index = count
        count += 1

        if invocation.request.messages.contains(
            where: {
                $0.role == .user
                    && $0.content.text.contains(
                        "previous response could not be decoded"
                    )
            }
        ) {
            repairRequestSeen = true
        }

        if invocation.request.messages.contains(
            where: {
                $0.role == .assistant
                    && $0.content.text == "not-json"
            }
        ) {
            previousMalformedResponseSeen = true
        }

        return index
    }

    func invocationCount() -> Int {
        count
    }

    func sawRepairRequest() -> Bool {
        repairRequestSeen
    }

    func sawPreviousMalformedResponse() -> Bool {
        previousMalformedResponseSeen
    }
}

private struct NativeStructuredRecoveryFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let state: NativeStructuredRecoveryFixtureState

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let invocationIndex = await state.record(
            invocation: invocation
        )
        let text: String

        if invocationIndex == 0 {
            text = "not-json"
        } else {
            text = String(
                decoding: try JSONEncoder().encode(
                    "REPAIRED"
                ),
                as: UTF8.self
            )
        }

        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                content: AgentContent(
                    text: text
                )
            ),
            stopReason: .end_turn,
            usage: AgentUsage(
                inputTokens: 1,
                outputTokens: 1,
                totalTokens: 2
            )
        )
        let profile = AgentModelProfile(
            identifier: "native_structured_recovery_fixture_profile",
            gatewayIdentifier: "native_structured_recovery_fixture_gateway",
            model: "fixture",
            purposes: [
                invocation.selection.purpose,
            ],
            capabilities: [
                .text,
                .structured_output,
            ]
        )
        let route = AgentModelRoute(
            purpose: invocation.selection.purpose,
            profile: profile
        )

        return AgentModelInvocationResult(
            response: response,
            route: AgentModelRouteRecord(
                route: route,
                requestMetadata: invocation.metadata,
                responseMetadata: response.metadata
            )
        )
    }

    func stream(
        _ invocation: AgentModelInvocation
    ) -> AsyncThrowingStream<AgentModelInvocationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: NativeStructuredRecoveryFixtureError
                    .streamingUnsupported
            )
        }
    }
}

private func nativeStructuredRecoveryPolicy()
    -> Recovery.Policy
{
    Recovery.Policy(
        rules: [
            .init(
                match: .init(
                    kind: .structured_output_invalid,
                    stage: .decoding,
                    scope: .inference,
                    effectState: Recovery.EffectState.none,
                    retrySafety: .safe
                ),
                plan: .init(
                    steps: [
                        .init(
                            action: .repair_output,
                            limit: .once
                        ),
                    ]
                )
            ),
        ]
    )
}

private func nativeStructuredAdapterRecoveryDiagnostics()
    async throws
    -> [TestFlowDiagnostic]
{
    let adapter = NativeStructuredAdapter()
    let directIncident = try Expect.notNil(
        adapter.incident(
            for: NativeStructuredAdapterError.emptyResponse,
            stage: .decoding,
            inference: NativeStructuredRecoveryFixtureInference
                .definition.identifier,
            attemptIndex: 0,
            invocationIndex: 0
        ),
        "native structured adapter classifies its own decoding error"
    )

    try Expect.equal(
        directIncident.kind,
        .structured_output_invalid,
        "native structured decode error normalizes to structured_output_invalid"
    )
    try Expect.equal(
        directIncident.stage,
        .decoding,
        "adapter-local incident preserves decoding stage"
    )
    try Expect.equal(
        directIncident.metadata["adapter"],
        adapter.identifier.rawValue,
        "adapter-local incident retains concrete adapter identity"
    )

    let state = NativeStructuredRecoveryFixtureState()
    let catalog = try AgentInferenceAdapterCatalog(
        adapters: [
            adapter,
        ]
    )
    let executor = AgentInferenceExecutor(
        modelInvoker: NativeStructuredRecoveryFixtureModelInvoker(
            state: state
        ),
        adapters: catalog
    )
    let realization = AgentInferenceRealization(
        strategy: .direct,
        modelSelection: .executor,
        instructions: "Return the normalized fixture value.",
        budget: .singleAttempt,
        recovery: nativeStructuredRecoveryPolicy(),
        adapter: .native_structured
    )

    let result = try await executor.execute(
        NativeStructuredRecoveryFixtureInference.self,
        input: .init(
            value: "fixture"
        ),
        realization: realization
    )
    let attempt = try Expect.notNil(
        result.record.attempts.first,
        "native structured repair remains within one semantic attempt"
    )
    let recovery = try Expect.notNil(
        attempt.recoveries.first,
        "native structured adapter recovery is recorded"
    )

    try Expect.equal(
        result.output,
        "REPAIRED",
        "native structured adapter restores the typed output"
    )
    try Expect.equal(
        result.record.budgetUsage.attemptCount,
        1,
        "adapter repair does not create a second semantic attempt"
    )
    try Expect.equal(
        result.record.budgetUsage.invocationCount,
        2,
        "malformed response and adapter-authored repair are two provider invocations"
    )
    try Expect.equal(
        result.record.budgetUsage.totalTokens,
        4,
        "both successful provider responses remain in token accounting"
    )

    let firstSucceeded: Bool
    switch attempt.invocations[0].outcome {
    case .succeeded:
        firstSucceeded = true

    case .failed:
        firstSucceeded = false
    }

    let secondSucceeded: Bool
    switch attempt.invocations[1].outcome {
    case .succeeded:
        secondSucceeded = true

    case .failed:
        secondSucceeded = false
    }

    try Expect.equal(
        firstSucceeded,
        true,
        "malformed structured content still came from a successful provider invocation"
    )
    try Expect.equal(
        secondSucceeded,
        true,
        "repair response is a successful provider invocation"
    )
    try Expect.equal(
        recovery.incident.kind,
        .structured_output_invalid,
        "executor used adapter-local decode classification"
    )
    try Expect.equal(
        recovery.attempts.map(\.action),
        [.repair_output],
        "native structured recovery uses repair_output"
    )
    try Expect.equal(
        recovery.outcome,
        .recovered,
        "native structured repair completes mechanically"
    )
    try Expect.equal(
        await state.sawRepairRequest(),
        true,
        "second invocation contains the NativeStructuredAdapter repair instruction"
    )
    try Expect.equal(
        await state.sawPreviousMalformedResponse(),
        true,
        "repair context includes the previous malformed assistant response"
    )
    try Expect.equal(
        await state.invocationCount(),
        2,
        "fixture observed exactly two model invocations"
    )

    return [
        .field(
            "semantic_attempts",
            String(result.record.budgetUsage.attemptCount)
        ),
        .field(
            "model_invocations",
            String(result.record.budgetUsage.invocationCount)
        ),
        .field(
            "reported_tokens",
            String(result.record.budgetUsage.totalTokens ?? 0)
        ),
        .field(
            "incident",
            recovery.incident.kind.rawValue
        ),
        .field(
            "recovery_action",
            recovery.attempts.first?.action.rawValue
                ?? "none"
        ),
        .field(
            "repair_request",
            String(
                await state.sawRepairRequest()
            )
        ),
    ]
}

let nativeStructuredAdapterRecoveryFlows: [TestFlow] = [
    TestFlow(
        "native-structured-adapter-recovery",
        tags: [
            "adapters",
            "inference",
            "recovery",
            "structured-output",
            "repair",
        ]
    ) {
        try await nativeStructuredAdapterRecoveryDiagnostics()
    },
]
