import AWSConnector

public protocol BedrockModelRuntime: Sendable {
    func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error>
}

extension BedrockRuntimeClient: BedrockModelRuntime {
    public func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error> {
        converse.stream(
            request,
            modelIdentifier: modelIdentifier
        )
    }
}
