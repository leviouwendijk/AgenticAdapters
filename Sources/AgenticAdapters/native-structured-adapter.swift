import Agentic
import AgenticPrograms
import Foundation

public struct NativeStructuredAdapter:
    AgentInferenceAdapter,
    Sendable
{
    public let identifier: AgentInferenceAdapterIdentifier

    public init(
        identifier: AgentInferenceAdapterIdentifier = .native_structured
    ) {
        self.identifier = identifier
    }

    public func prepare<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation {
        var messages: [AgentMessage] = []

        let instructions = renderInstructions(
            definition: inference.definition,
            realization: realization
        )

        if !instructions.isEmpty {
            messages.append(
                AgentMessage(
                    role: .system,
                    content: AgentContent(
                        text: instructions
                    )
                )
            )
        }

        for demonstration in realization.demonstrations {
            messages.append(
                AgentMessage(
                    role: .user,
                    content: AgentContent(
                        text: try renderJSON(
                            demonstration.input
                        )
                    )
                )
            )

            messages.append(
                AgentMessage(
                    role: .assistant,
                    content: AgentContent(
                        text: try renderJSON(
                            demonstration.output
                        )
                    )
                )
            )
        }

        messages.append(
            AgentMessage(
                role: .user,
                content: AgentContent(
                    text: try renderInput(
                        input
                    )
                )
            )
        )

        return AgentInferenceAdaptation(
            request: AgentRequest(
                messages: messages,
                generationConfiguration: realization.generation,
                responseFormat: .jsonschema(
                    Inference.Output.jsonschema
                ),
                metadata: [
                    "inference.adapter": identifier.rawValue,
                    "inference.identifier": inference.definition.identifier.rawValue,
                    "inference.strategy": realization.strategy.rawValue,
                ]
            ),
            requirements: AgentModelRequirements(
                capabilities: [
                    .structured_output,
                ]
            )
        )
    }

    public func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output {
        let text = response.message.content.text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !text.isEmpty else {
            throw NativeStructuredAdapterError.emptyResponse
        }

        do {
            return try JSONDecoder().decode(
                Inference.Output.self,
                from: Data(
                    text.utf8
                )
            )
        } catch {
            throw NativeStructuredAdapterError.invalidResponse(
                String(
                    describing: error
                )
            )
        }
    }
}

private extension NativeStructuredAdapter {
    func renderInstructions(
        definition: AgentInferenceDefinition,
        realization: AgentInferenceRealization
    ) -> String {
        var sections: [String] = []

        let purpose = definition.purpose
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !purpose.isEmpty {
            sections.append(
                "Purpose:\n\(purpose)"
            )
        }

        let instructions = realization.instructions
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !instructions.isEmpty {
            sections.append(
                "Instructions:\n\(instructions)"
            )
        }

        return sections.joined(
            separator: "\n\n"
        )
    }

    func renderInput<Input: Encodable & Sendable>(
        _ input: Input
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return String(
            decoding: try encoder.encode(
                input
            ),
            as: UTF8.self
        )
    }

    func renderJSON<Value: Encodable>(
        _ value: Value
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return String(
            decoding: try encoder.encode(
                value
            ),
            as: UTF8.self
        )
    }
}
