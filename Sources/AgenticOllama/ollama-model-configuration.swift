import Foundation

public struct OllamaModelConfiguration: Sendable {
    public let endpoint: URL
    public let contextWindow: Int
    public let thinking: Bool
    public let metadata: [String: String]

    public init(
        endpoint: URL,
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws {
        guard let scheme = endpoint.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              endpoint.host != nil
        else {
            throw OllamaAdapterError.invalidEndpoint(endpoint.absoluteString)
        }

        self.endpoint = endpoint
        self.contextWindow = contextWindow
        self.thinking = thinking
        self.metadata = metadata
    }
}
