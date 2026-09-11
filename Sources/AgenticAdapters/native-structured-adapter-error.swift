import Foundation

public enum NativeStructuredAdapterError:
    Error,
    Sendable,
    LocalizedError
{
    case emptyResponse
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Native structured inference returned no textual response content."

        case .invalidResponse(let reason):
            return "Native structured inference response could not be decoded: \(reason)"
        }
    }
}
