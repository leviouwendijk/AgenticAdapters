import Agentic
import Foundation
import Primitives

#if canImport(FoundationModels)
import FoundationModels


@available(macOS 26.0, *)
package struct AppleFoundationModelToolProxy: Tool {
    package typealias Arguments = GeneratedContent
    package typealias Output = String

    package let name: String
    package let description: String
    package let parameters: GenerationSchema
    package let includesSchemaInInstructions = true

    private let resolver: any AgentToolCallResolver

    package init(
        definition: AgentToolDefinition,
        resolver: any AgentToolCallResolver
    ) throws {
        self.name = definition.name
        self.description = definition.description
        self.parameters = try AppleFoundationModelToolSchemaLowerer.parameters(
            for: definition
        )
        self.resolver = resolver
    }

    package func call(arguments: GeneratedContent) async throws -> String {
        let input: JSONValue

        do {
            input = try JSONDecoder().decode(
                JSONValue.self,
                from: Data(arguments.jsonString.utf8)
            )
        } catch {
            throw AppleFoundationModelError.toolArgumentsInvalid(
                tool: name,
                detail: String(describing: error)
            )
        }

        let result = try await resolver.resolve(
            AgentToolCall(
                id: UUID().uuidString,
                name: name,
                input: input
            )
        )

        return try AppleFoundationModelToolOutputRenderer.render(
            result
        )
    }
}

@available(macOS 26.0, *)
package enum AppleFoundationModelToolBridge {
    package static func tools(
        for definitions: [AgentToolDefinition],
        resolver: any AgentToolCallResolver
    ) throws -> [AppleFoundationModelToolProxy] {
        try definitions.map { definition in
            try AppleFoundationModelToolProxy(
                definition: definition,
                resolver: resolver
            )
        }
    }
}

@available(macOS 26.0, *)
package enum AppleFoundationModelToolOutputRenderer {
    package static func render(
        _ result: AgentToolResult
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        let data = try encoder.encode(
            result.output
        )

        guard let output = String(
            data: data,
            encoding: .utf8
        ) else {
            throw AppleFoundationModelError.generationFailed(
                "Could not encode tool output as UTF-8 JSON"
            )
        }

        guard result.isError else {
            return output
        }

        return "Tool execution failed: \(output)"
    }
}

@available(macOS 26.0, *)
package enum AppleFoundationModelToolSchemaLowerer {
    package static func parameters(
        for definition: AgentToolDefinition
    ) throws -> GenerationSchema {
        let rootObject: [String: Any]

        if let inputSchema = definition.inputSchema {
            let data = try JSONEncoder().encode(inputSchema)
            let value = try JSONSerialization.jsonObject(with: data)

            guard let object = value as? [String: Any] else {
                throw unsupported(
                    tool: definition.name,
                    path: "$",
                    detail: "Tool input schema must be a JSON object."
                )
            }

            rootObject = object
        } else {
            rootObject = [
                "type": "object",
                "properties": [String: Any]()
            ]
        }

        let rootName = schemaName(
            definition.name + "_arguments"
        )
        let root = try dynamicSchema(
            from: rootObject,
            name: rootName,
            tool: definition.name,
            path: "$"
        )

        return try GenerationSchema(
            root: root,
            dependencies: []
        )
    }
}

@available(macOS 26.0, *)
private extension AppleFoundationModelToolSchemaLowerer {
    static func dynamicSchema(
        from object: [String: Any],
        name: String,
        tool: String,
        path: String
    ) throws -> DynamicGenerationSchema {
        let description = object["description"] as? String

        if let enumValues = object["enum"] as? [Any] {
            let strings = enumValues.compactMap { value in
                value as? String
            }

            if !strings.isEmpty {
                return DynamicGenerationSchema(
                    name: name,
                    description: description,
                    anyOf: strings
                )
            }
        }

        if let alternatives = alternativeObjects(in: object),
           !alternatives.isEmpty {
            let nonNull = alternatives.filter { alternative in
                typeName(in: alternative) != "null"
            }
            let schemas = try nonNull.enumerated().map { index, alternative in
                try dynamicSchema(
                    from: alternative,
                    name: schemaName("\(name)_alternative_\(index)"),
                    tool: tool,
                    path: path
                )
            }

            guard !schemas.isEmpty else {
                throw unsupported(
                    tool: tool,
                    path: path,
                    detail: "A schema containing only null cannot describe tool arguments."
                )
            }

            if schemas.count == 1, let schema = schemas.first {
                return schema
            }

            return DynamicGenerationSchema(
                name: name,
                description: description,
                anyOf: schemas
            )
        }

        let type = typeName(in: object)
            ?? (object["properties"] == nil ? nil : "object")
            ?? "object"

        switch type {
        case "object":
            let rawProperties = object["properties"] as? [String: Any] ?? [:]
            let required = Set(object["required"] as? [String] ?? [])
            let properties = try rawProperties.keys.sorted().map { propertyName in
                guard let propertyObject = rawProperties[propertyName] as? [String: Any] else {
                    throw unsupported(
                        tool: tool,
                        path: "\(path).properties.\(propertyName)",
                        detail: "Property schema must be a JSON object."
                    )
                }

                let propertySchema = try dynamicSchema(
                    from: propertyObject,
                    name: schemaName("\(name)_\(propertyName)"),
                    tool: tool,
                    path: "\(path).properties.\(propertyName)"
                )

                return DynamicGenerationSchema.Property(
                    name: propertyName,
                    description: propertyObject["description"] as? String,
                    schema: propertySchema,
                    isOptional: !required.contains(propertyName)
                )
            }

            return DynamicGenerationSchema(
                name: name,
                description: description,
                properties: properties
            )

        case "array":
            guard let items = object["items"] as? [String: Any] else {
                throw unsupported(
                    tool: tool,
                    path: path,
                    detail: "Array schemas must provide an object-valued items schema."
                )
            }

            return DynamicGenerationSchema(
                arrayOf: try dynamicSchema(
                    from: items,
                    name: schemaName(name + "_item"),
                    tool: tool,
                    path: path + ".items"
                ),
                minimumElements: integer(object["minItems"]),
                maximumElements: integer(object["maxItems"])
            )

        case "string":
            return DynamicGenerationSchema(type: String.self)

        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)

        case "integer":
            return DynamicGenerationSchema(type: Int.self)

        case "number":
            return DynamicGenerationSchema(type: Double.self)

        default:
            throw unsupported(
                tool: tool,
                path: path,
                detail: "Unsupported JSON Schema type '\(type)'."
            )
        }
    }

    static func typeName(
        in object: [String: Any]
    ) -> String? {
        if let type = object["type"] as? String {
            return type
        }

        if let types = object["type"] as? [String] {
            return types.first { type in
                type != "null"
            }
        }

        return nil
    }

    static func alternativeObjects(
        in object: [String: Any]
    ) -> [[String: Any]]? {
        if let anyOf = object["anyOf"] as? [[String: Any]] {
            return anyOf
        }

        return object["oneOf"] as? [[String: Any]]
    }

    static func integer(
        _ value: Any?
    ) -> Int? {
        if let value = value as? Int {
            return value
        }

        return (value as? NSNumber)?.intValue
    }

    static func schemaName(
        _ rawValue: String
    ) -> String {
        let sanitized = rawValue.replacingOccurrences(
            of: "[^A-Za-z0-9_]",
            with: "_",
            options: .regularExpression
        )

        guard let first = sanitized.first,
              first.isLetter || first == "_" else {
            return "Agentic_" + sanitized
        }

        return sanitized.isEmpty ? "AgenticArguments" : sanitized
    }

    static func unsupported(
        tool: String,
        path: String,
        detail: String
    ) -> AppleFoundationModelError {
        .toolSchemaUnsupported(
            tool: tool,
            detail: "\(path): \(detail)"
        )
    }
}
#endif
