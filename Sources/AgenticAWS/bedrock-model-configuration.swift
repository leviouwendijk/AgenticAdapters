public struct BedrockModelConfiguration: Sendable {
    public let runtime: any BedrockModelRuntime
    public let defaultModelIdentifier: String
    public let metadata: [String: String]

    public init(
        runtime: any BedrockModelRuntime,
        defaultModelIdentifier: String,
        metadata: [String: String] = [:]
    ) {
        self.runtime = runtime
        self.defaultModelIdentifier = defaultModelIdentifier
        self.metadata = metadata
    }
}
