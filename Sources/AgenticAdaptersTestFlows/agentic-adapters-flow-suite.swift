import TestFlows

enum AgenticAdaptersFlowSuite: TestFlowRegistry {
    static let title = "AgenticAdapters flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            ID.apple_prompt_rendering,
            tags: ["apple", "foundation-models", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runApplePromptRendering()
        },
        TestFlow(
            ID.apple_tool_bridge,
            tags: ["apple", "foundation-models", "tool-use", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAppleToolBridge()
        },
        TestFlow(
            ID.bedrock_buffered_stream_completion,
            tags: ["aws", "bedrock", "offline", "stream"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockBufferedStreamCompletion()
        },
        TestFlow(
            ID.bedrock_tool_use_stream,
            tags: ["aws", "bedrock", "offline", "tool-use", "stream"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockToolUseStream()
        },
        TestFlow(
            ID.bedrock_tool_result_mapping,
            tags: ["aws", "bedrock", "offline", "tool-use"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockToolResultMapping()
        },
        TestFlow(
            ID.bedrock_model_handle_profile_synthesis,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockModelHandleProfileSynthesis()
        },
        TestFlow(
            ID.bedrock_non_streaming_handle_drops_streaming_capability,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockNonStreamingHandleDropsStreamingCapability()
        },
        TestFlow(
            ID.bedrock_generic_snapshot_provider_catalog,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockGenericSnapshotProviderCatalog()
        },
        TestFlow(
            ID.bedrock_discovery_tool_registration,
            tags: ["aws", "bedrock", "model-discovery", "tools", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockDiscoveryToolRegistration()
        },
        TestFlow(
            ID.bedrock_live_nested_profile_api,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "live"]
        ) {
            try await AgenticAdaptersFlowTesting.runBedrockLiveNestedProfileAPI()
        },
    ]
}

extension AgenticAdaptersFlowSuite {
    enum ID {
        static let apple_prompt_rendering = "apple-prompt-rendering"
        static let apple_tool_bridge = "apple-tool-bridge"
        static let bedrock_buffered_stream_completion = "bedrock-buffered-stream-completion"
        static let bedrock_tool_use_stream = "bedrock-tool-use-stream"
        static let bedrock_tool_result_mapping = "bedrock-tool-result-mapping"
        static let bedrock_model_handle_profile_synthesis = "bedrock-model-handle-profile-synthesis"
        static let bedrock_non_streaming_handle_drops_streaming_capability = "bedrock-non-streaming-handle-drops-streaming-capability"
        static let bedrock_generic_snapshot_provider_catalog = "bedrock-generic-snapshot-provider-catalog"
        static let bedrock_discovery_tool_registration = "bedrock-discovery-tool-registration"
        static let bedrock_live_nested_profile_api = "bedrock-live-nested-profile-api"
    }
}
