import Agentic
import Foundation

package enum AppleFoundationModelSelectedModel: Sendable, Hashable {
    case system

    package init(
        parsing rawValue: String
    ) throws {
        let value = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch value {
        case "", "default", "system", "system.default":
            self = .system

        default:
            throw AppleFoundationModelError.namedModelUnsupported(
                value
            )
        }
    }
}

/// Parsed, retained Apple invocation state.
///
/// Generic Agentic route/request semantics are interpreted exactly once when
/// this value is created. Provider execution consumes this stronger value
/// rather than repeatedly inspecting weak strings or unsupported content.
package struct AppleFoundationModelInvocation: Sendable {
    package let request: AgentRequest
    package let model: AppleFoundationModelSelectedModel
    package let selectedModelIdentifier: String
    package let context: AgentModelInvocationContext

    package init(
        parsing request: AgentRequest,
        route: AgentModelRoute,
        context: AgentModelInvocationContext
    ) throws {
        let resources = request.messages.flatMap {
            $0.content.resources
        }

        guard resources.isEmpty else {
            throw AppleFoundationModelError.resourcesUnsupported(
                resources.map(\.id)
            )
        }

        self.request = request
        self.model = try AppleFoundationModelSelectedModel(
            parsing: route.profile.model
        )
        self.selectedModelIdentifier = route.profile.model
        self.context = context
    }
}
