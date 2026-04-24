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
            ID.apple_tools_unsupported,
            tags: ["apple", "foundation-models", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAppleToolsUnsupported()
        },

        TestFlow(
            ID.adapter_stream_supported,
            tags: ["adapter", "stream", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAdapterStreamSupported()
        },

        TestFlow(
            ID.adapter_tool_loop,
            tags: ["adapter", "tool-use", "stream", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAdapterToolLoop()
        },

        TestFlow(
            ID.adapter_scratchpad_tool,
            tags: ["adapter", "tool-use", "scratchpad", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAdapterScratchpadTool()
        },

        TestFlow(
            ID.adapter_scratchpad_read_write_loop,
            tags: ["adapter", "tool-use", "scratchpad", "loop", "offline"]
        ) {
            try await AgenticAdaptersFlowTesting.runAdapterScratchpadReadWriteLoop()
        },

        TestFlow(
            ID.apple_live_query,
            tags: ["apple", "foundation-models", "live"]
        ) {
            try await AgenticAdaptersFlowTesting.runAppleLiveQuery()
        },

        TestFlow(
            ID.apple_live_stream_query,
            tags: ["apple", "foundation-models", "stream", "live"]
        ) {
            try await AgenticAdaptersFlowTesting.runAppleLiveStreamQuery()
        },

        TestFlow(
            ID.apple_live_scratchpad_read_write_loop,
            tags: ["apple", "foundation-models", "tool-use", "scratchpad", "loop", "live"]
        ) {
            try await AgenticAdaptersFlowTesting.runAppleLiveScratchpadReadWriteLoop()
        },
    ]
}

extension AgenticAdaptersFlowSuite {
    enum ID {
        static let apple_prompt_rendering = "apple-prompt-rendering"
        static let apple_tools_unsupported = "apple-tools-unsupported"
        static let adapter_stream_supported = "adapter-stream-supported"
        static let adapter_tool_loop = "adapter-tool-loop"
        static let adapter_scratchpad_tool = "adapter-scratchpad-tool"
        static let adapter_scratchpad_read_write_loop = "adapter-scratchpad-read-write-loop"
        static let apple_live_query = "apple-live-query"
        static let apple_live_stream_query = "apple-live-stream-query"
        static let apple_live_scratchpad_read_write_loop = "apple-live-scratchpad-read-write-loop"
    }
}
