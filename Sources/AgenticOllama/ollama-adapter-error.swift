import Agentic
import Foundation

public enum OllamaAdapterError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidEndpoint(String)
    case emptyMessages
    case emptyMappedMessages
    case unsupportedContent(AgentRole)
    case missingToolName(String)
    case missingTLSCACertificateConfiguration(
        symbol: String
    )
    case invalidTLSCACertificate(
        path: String,
        reason: String
    )
    case invalidHTTPResponse
    case httpStatus(Int)
    case invalidStreamFrame(String)
    case streamEndedWithoutResponse

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let value):
            return "Invalid Ollama endpoint: \(value)"

        case .emptyMessages:
            return "Ollama adapter received a request with no messages."

        case .emptyMappedMessages:
            return "Ollama adapter produced no Ollama messages."

        case .unsupportedContent(let role):
            return "Ollama adapter does not support one or more \(role.rawValue) content blocks in this first text/tool implementation."

        case .missingToolName(let id):
            return "Ollama adapter could not resolve the tool name for result '\(id)'."

        case .missingTLSCACertificateConfiguration(
            let symbol
        ):
            return "HTTPS Ollama endpoint requires a trusted CA certificate path. Set \(symbol) to the CA certificate file path."

        case .invalidTLSCACertificate(
            let path,
            let reason
        ):
            return "Ollama trusted CA certificate at '\(path)' could not be loaded: \(reason)"

        case .invalidHTTPResponse:
            return "Ollama endpoint returned a non-HTTP response."

        case .httpStatus(let status):
            return "Ollama endpoint returned HTTP status \(status)."

        case .invalidStreamFrame(let line):
            return "Ollama adapter could not decode a streamed NDJSON frame: \(line)"

        case .streamEndedWithoutResponse:
            return "Ollama stream ended without a completed response."
        }
    }
}
