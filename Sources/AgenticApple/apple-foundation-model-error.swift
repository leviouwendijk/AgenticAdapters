import Foundation

public enum AppleFoundationModelError: Error, Sendable, Equatable, LocalizedError {
    case foundationModelsUnavailable
    case operatingSystemUnavailable
    case modelUnavailable(String)
    case namedModelUnsupported(String)
    case toolsUnsupported([String])
    case streamingUnsupported
    case emptyPrompt
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .foundationModelsUnavailable:
            return "FoundationModels is not available to this build."

        case .operatingSystemUnavailable:
            return "FoundationModels requires an operating system version that supports the framework."

        case .modelUnavailable(let reason):
            return "The system language model is unavailable: \(reason)."

        case .namedModelUnsupported(let model):
            return "FoundationModels adapter V1 only supports the default system model; requested '\(model)'."

        case .toolsUnsupported(let tools):
            return "FoundationModels adapter V1 does not support tool bridging yet: \(tools.joined(separator: ", "))."

        case .streamingUnsupported:
            return "FoundationModels adapter V1 only supports buffered responses."

        case .emptyPrompt:
            return "FoundationModels adapter received an empty prompt."

        case .generationFailed(let message):
            return "FoundationModels generation failed: \(message)."
        }
    }
}
