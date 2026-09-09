import Agentic
import Schema

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
package enum AppleFoundationModelResponseFormat {
    case text
    case jsonschema(GenerationSchema)

    package init(
        parsing format: AgentResponseFormat
    ) throws {
        switch format {
        case .text:
            self = .text

        case .jsonschema(let schema):
            self = .jsonschema(
                try AppleFoundationModelGenerationSchemaLowerer.response(
                    schema.jsonvalue
                )
            )
        }
    }
}
#endif
