import TestFlows

@main
enum AgenticAdaptersFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticAdaptersFlowSuite.self
        )
    }
}
