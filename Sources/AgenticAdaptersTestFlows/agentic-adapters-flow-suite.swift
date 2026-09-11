import TestFlows

enum AgenticAdaptersFlowSuite: TestFlowRegistry {
    static let title = "AgenticAdapters flow tests"

    static let flows: [TestFlow] =
        AgentInferenceAdapterSubstrateFlowTests.all
            + NativeStructuredAdapterFlowTests.all
}
