public struct BedrockModelDiscoveryOptions: Sendable, Codable, Hashable {
    public var modelProvider: String?
    public var modelOutputModality: String?
    public var profileType: String?
    public var includeInactiveProfiles: Bool
    public var includeLegacy: Bool
    public var maxProfileResults: Int?

    public init(
        modelProvider: String? = nil,
        modelOutputModality: String? = "TEXT",
        profileType: String? = nil,
        includeInactiveProfiles: Bool = false,
        includeLegacy: Bool = false,
        maxProfileResults: Int? = 100
    ) {
        self.modelProvider = modelProvider
        self.modelOutputModality = modelOutputModality
        self.profileType = profileType
        self.includeInactiveProfiles = includeInactiveProfiles
        self.includeLegacy = includeLegacy
        self.maxProfileResults = maxProfileResults
    }

    public static let `default` = Self()
}
