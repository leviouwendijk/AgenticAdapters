import TestFlows

@main
struct AgenticAdaptersFlowTesting {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticAdaptersFlowSuite.self
        )
    }
}
