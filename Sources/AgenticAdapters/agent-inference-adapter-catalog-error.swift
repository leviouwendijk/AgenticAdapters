import Foundation

public enum AgentInferenceAdapterCatalogError:
    Error,
    Sendable,
    LocalizedError
{
    case duplicateAdapter(String)
    case unknownAdapter(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateAdapter(let identifier):
            return "An inference adapter with id '\(identifier)' is already registered."

        case .unknownAdapter(let identifier):
            return "Unknown inference adapter: \(identifier)"
        }
    }
}
