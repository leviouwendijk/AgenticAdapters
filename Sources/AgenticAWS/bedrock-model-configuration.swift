public struct BedrockModelConfiguration: Sendable {
    public let runtime: any BedrockModelRuntime
    public let defaultModelIdentifier: String
    public let metadata: [String: String]
    public let diagnostics: BedrockDiagnostics

    public init(
        runtime: any BedrockModelRuntime,
        defaultModelIdentifier: String,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.runtime = runtime
        self.defaultModelIdentifier = defaultModelIdentifier
        self.metadata = metadata
        self.diagnostics = diagnostics
    }
}
