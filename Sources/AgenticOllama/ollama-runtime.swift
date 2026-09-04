import Cryptography
import Foundation

enum OllamaURLSessionTrust: Sendable {
    case system
    case privateCA(
        caCertificatePathSymbol: String
    )
}

struct OllamaURLSessionRuntime: Sendable {
    let trust: OllamaURLSessionTrust

    init(
        trust: OllamaURLSessionTrust = .system
    ) {
        self.trust = trust
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
                    urlRequest.setValue(
                        "application/json",
                        forHTTPHeaderField: "Content-Type"
                    )
                    urlRequest.httpBody = try JSONEncoder().encode(
                        request
                    )

                    func consume(
                        session: URLSession,
                        delegate: (any URLSessionTaskDelegate)? = nil
                    ) async throws {
                        let (bytes, response) = try await session.bytes(
                            for: urlRequest,
                            delegate: delegate
                        )

                        guard let response =
                            response as? HTTPURLResponse
                        else {
                            throw OllamaAdapterError
                                .invalidHTTPResponse
                        }

                        guard (200..<300).contains(
                            response.statusCode
                        ) else {
                            throw OllamaAdapterError.httpStatus(
                                response.statusCode
                            )
                        }

                        let decoder = JSONDecoder()

                        for try await line in bytes.lines {
                            if Task.isCancelled {
                                throw CancellationError()
                            }

                            guard !line.isEmpty else {
                                continue
                            }

                            guard let data = line.data(
                                using: .utf8
                            ) else {
                                throw OllamaAdapterError
                                    .invalidStreamFrame(line)
                            }

                            do {
                                continuation.yield(
                                    try decoder.decode(
                                        OllamaChatChunk.self,
                                        from: data
                                    )
                                )
                            } catch {
                                throw OllamaAdapterError
                                    .invalidStreamFrame(line)
                            }
                        }
                    }

                    switch trust {
                    case .system:
                        try await consume(
                            session: .shared
                        )

                    case .privateCA(
                        let caCertificatePathSymbol
                    ):
                        try await CryptographicCATrustedURLSession
                            .withSession(
                                caCertificatePathSymbol:
                                    caCertificatePathSymbol,
                                allowedHost: endpoint.host,
                                anchorOnly: true,
                                policyMode: .basicX509
                            ) { session, delegate in
                                try await consume(
                                    session: session,
                                    delegate: delegate
                                )
                            }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
