import AWSConnector

public protocol BedrockModelRuntime: Sendable {
    func respond(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) async throws -> Bedrock.Converse.Response

    func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error>
}

extension BedrockRuntimeClient: BedrockModelRuntime {
    public func respond(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String
    ) async throws -> Bedrock.Converse.Response {
        try await converse.respond(
            request,
            modelIdentifier: modelIdentifier
        )
    }

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
