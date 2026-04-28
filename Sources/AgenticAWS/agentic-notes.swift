import Agentic

enum AgenticAdapterSemanticStreamingNotes {
    /*
     Provider-specific reasoning or "thinking" text should not remain a
     terminal-side regex concern long term.

     Desired direction:
     - Adapters identify provider-native reasoning/thinking blocks where the
       provider exposes them structurally.
     - Agentic grows a semantic stream/content primitive once both Apple and
       AWS behavior are clearer.
     - Interfaces render reasoning differently from final assistant text:
       dimmed, collapsible, or hidden depending on host policy.
     - Plain text tags such as <thinking>...</thinking> may be normalized by
       adapters as an interim compatibility step, but should not be the final
       cross-provider contract.

     Candidate future shapes:
     - AgentStreamEvent.reasoningDelta(String)
     - AgentContentBlock.reasoning(String)
     - AgentContentBlock.annotation(kind:source:text:)
     */
}
