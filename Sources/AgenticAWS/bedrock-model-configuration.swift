public struct BedrockModelConfiguration: Sendable {
    public let runtime: any BedrockModelRuntime
    public let metadata: [String: String]
    public let diagnostics: BedrockDiagnostics

    public init(
        runtime: any BedrockModelRuntime,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.runtime = runtime
        self.metadata = metadata
        self.diagnostics = diagnostics
    }
}
