public struct BedrockDiagnostics: Sendable, Codable, Hashable {
    public var raw: Bool

    public init(
        raw: Bool = false
    ) {
        self.raw = raw
    }

    public static let disabled = Self()
}
