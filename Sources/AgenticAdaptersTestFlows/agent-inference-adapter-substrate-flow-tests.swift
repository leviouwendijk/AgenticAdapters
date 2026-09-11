import Agentic
import AgenticAdapters
import AgenticInference
import TestFlows

enum AgentInferenceAdapterSubstrateFlowTests {
    static let all: [TestFlow] = [
        TestFlow(
            "inference-adapter-adaptation",
            tags: [
                "adapters",
                "inference",
            ]
        ) {
            try adaptationDiagnostics()
        },
        TestFlow(
            "inference-adapter-catalog",
            tags: [
                "adapters",
                "catalog",
            ]
        ) {
            try catalogDiagnostics()
        },
    ]

    static func adaptationDiagnostics() throws -> [TestFlowDiagnostic] {
        let adaptation = AgentInferenceAdaptation(
            request: AgentRequest(
                messages: []
            )
        )

        try Expect.true(
            adaptation.requirements.capabilities.isEmpty,
            "adaptation contributes no model requirements by default"
        )

        try Expect.equal(
            adaptation.request.messages.count,
            0,
            "adaptation retains generic AgentRequest"
        )

        return [
            .field(
                "requirements",
                "\(adaptation.requirements.capabilities.count)"
            ),
            .field(
                "messages",
                "\(adaptation.request.messages.count)"
            ),
        ]
    }

    static func catalogDiagnostics() throws -> [TestFlowDiagnostic] {
        var catalog = AgentInferenceAdapterCatalog()

        try Expect.true(
            catalog.isEmpty,
            "catalog starts empty"
        )

        try catalog.register(
            ProbeInferenceAdapter(
                identifier: "probe_b"
            )
        )
        try catalog.register(
            ProbeInferenceAdapter(
                identifier: "probe_a"
            )
        )

        try Expect.equal(
            catalog.count,
            2,
            "catalog count"
        )

        try Expect.equal(
            catalog.identifiers.map(\.rawValue),
            [
                "probe_a",
                "probe_b",
            ],
            "catalog identifiers are deterministic"
        )

        let resolved = try catalog.require(
            "probe_a"
        )

        try Expect.equal(
            resolved.identifier.rawValue,
            "probe_a",
            "catalog resolves registered adapter"
        )

        try Expect.true(
            catalog.adapter(
                for: "missing"
            ) == nil,
            "optional catalog lookup returns nil for unknown adapter"
        )

        do {
            try catalog.register(
                ProbeInferenceAdapter(
                    identifier: "probe_a"
                )
            )

            throw TestFlowAssertionFailure(
                label: "duplicate adapter",
                message: "duplicate registration did not throw"
            )
        } catch let error as AgentInferenceAdapterCatalogError {
            switch error {
            case .duplicateAdapter(let identifier):
                try Expect.equal(
                    identifier,
                    "probe_a",
                    "duplicate error retains adapter identifier"
                )

            case .unknownAdapter:
                throw TestFlowAssertionFailure(
                    label: "duplicate adapter",
                    message: "received unknown-adapter error for duplicate registration"
                )
            }
        }

        do {
            _ = try catalog.require(
                "missing"
            )

            throw TestFlowAssertionFailure(
                label: "unknown adapter",
                message: "unknown adapter lookup did not throw"
            )
        } catch let error as AgentInferenceAdapterCatalogError {
            switch error {
            case .unknownAdapter(let identifier):
                try Expect.equal(
                    identifier,
                    "missing",
                    "unknown error retains adapter identifier"
                )

            case .duplicateAdapter:
                throw TestFlowAssertionFailure(
                    label: "unknown adapter",
                    message: "received duplicate-adapter error for unknown lookup"
                )
            }
        }

        return [
            .field(
                "count",
                "\(catalog.count)"
            ),
            .field(
                "identifiers",
                catalog.identifiers
                    .map(\.rawValue)
                    .joined(
                        separator: ","
                    )
            ),
        ]
    }
}

private struct ProbeInferenceAdapter: AgentInferenceAdapter {
    let identifier: AgentInferenceAdapterIdentifier

    func prepare<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation {
        AgentInferenceAdaptation(
            request: AgentRequest(
                messages: []
            )
        )
    }

    func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output {
        throw ProbeInferenceAdapterError.decodingNotImplemented
    }
}

private enum ProbeInferenceAdapterError:
    Error,
    Sendable
{
    case decodingNotImplemented
}
