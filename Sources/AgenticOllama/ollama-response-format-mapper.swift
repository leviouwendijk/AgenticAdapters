import Agentic
import Primitives
import Schema

/// Final provider-boundary lowering from Agentic response semantics into
/// Ollama's request format representation.
enum OllamaResponseFormatMapper {
    static func map(
        _ format: AgentResponseFormat
    ) -> JSONValue? {
        switch format {
        case .text:
            return nil

        case .jsonschema(let schema):
            return schema.jsonvalue
        }
    }
}
