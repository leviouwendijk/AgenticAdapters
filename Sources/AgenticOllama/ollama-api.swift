import Primitives

struct OllamaChatRequest: Sendable, Encodable {
    let model: String
    let messages: [OllamaChatMessage]
    let tools: [OllamaTool]?
    let stream: Bool
    let think: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Sendable, Codable {
    let numCtx: Int
    let numPredict: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?

    enum CodingKeys: String, CodingKey {
        case numCtx = "num_ctx"
        case numPredict = "num_predict"
        case temperature
        case topP = "top_p"
        case stop
    }
}

struct OllamaChatMessage: Sendable, Codable {
    let role: String
    let content: String
    let thinking: String?
    let toolCalls: [OllamaToolCall]?
    let toolName: String?

    init(
        role: String,
        content: String = "",
        thinking: String? = nil,
        toolCalls: [OllamaToolCall]? = nil,
        toolName: String? = nil
    ) {
        self.role = role
        self.content = content
        self.thinking = thinking
        self.toolCalls = toolCalls
        self.toolName = toolName
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case thinking
        case toolCalls = "tool_calls"
        case toolName = "tool_name"
    }
}

struct OllamaTool: Sendable, Encodable {
    let type: String
    let function: OllamaToolDefinition
}

struct OllamaToolDefinition: Sendable, Encodable {
    let name: String
    let description: String
    let parameters: JSONValue
}

struct OllamaToolCall: Sendable, Codable {
    let id: String
    let function: OllamaFunctionCall
}

struct OllamaFunctionCall: Sendable, Codable {
    let index: Int?
    let name: String
    let arguments: JSONValue
}

struct OllamaChatChunk: Sendable, Decodable {
    let model: String?
    let message: OllamaChatMessage?
    let done: Bool
    let doneReason: String?
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalCount: Int?
    let promptEvalDuration: Int64?
    let evalCount: Int?
    let evalDuration: Int64?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case doneReason = "done_reason"
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}
