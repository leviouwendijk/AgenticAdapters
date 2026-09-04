import Foundation

struct OllamaURLSessionRuntime: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(
        _ request: OllamaChatRequest,
        endpoint: URL
    ) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = endpoint
                        .appendingPathComponent("api")
                        .appendingPathComponent("chat")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let response = response as? HTTPURLResponse else {
                        throw OllamaAdapterError.invalidHTTPResponse
                    }
                    guard (200..<300).contains(response.statusCode) else {
                        throw OllamaAdapterError.httpStatus(response.statusCode)
                    }

                    let decoder = JSONDecoder()
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        guard !line.isEmpty else { continue }
                        guard let data = line.data(using: .utf8) else {
                            throw OllamaAdapterError.invalidStreamFrame(line)
                        }
                        do {
                            continuation.yield(try decoder.decode(OllamaChatChunk.self, from: data))
                        } catch {
                            throw OllamaAdapterError.invalidStreamFrame(line)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
