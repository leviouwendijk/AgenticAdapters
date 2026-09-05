import Cryptography
import Foundation
import Milieu

enum OllamaURLSessionTrust: Sendable {
    case system
    case privateCA(
        caCertificatePathSymbol: String
    )

    static let caCertificatePathSymbol =
        "AGENTIC_MODEL_OLLAMA_CA_CERTIFICATE_PATH"

    static func resolve(
        for endpoint: URL
    ) throws -> Self {
        guard endpoint.scheme?.lowercased() == "https" else {
            return .system
        }

        do {
            _ = try EnvironmentExtractor.value(
                caCertificatePathSymbol
            )
        } catch {
            throw OllamaAdapterError
                .missingTLSCACertificateConfiguration(
                    symbol: caCertificatePathSymbol
                )
        }

        return .privateCA(
            caCertificatePathSymbol:
                caCertificatePathSymbol
        )
    }

    var diagnosticName: String {
        switch self {
        case .system:
            return "system"

        case .privateCA:
            return "private_ca"
        }
    }
}

struct OllamaURLSessionRuntime: Sendable {
    let trust: OllamaURLSessionTrust

    init(
        trust: OllamaURLSessionTrust
    ) {
        self.trust = trust
    }

    func respond(
        _ request: OllamaChatRequest,
        endpoint: URL
    ) async throws -> OllamaChatChunk {
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

        let data: Data
        let response: URLResponse

        do {
            switch trust {
            case .system:
                (data, response) = try await URLSession.shared.data(
                    for: urlRequest
                )

            case .privateCA(let caCertificatePathSymbol):
                (data, response) = try await
                    CryptographicCATrustedURLSession.data(
                        for: urlRequest,
                        caCertificatePathSymbol:
                            caCertificatePathSymbol,
                        allowedHost: endpoint.host,
                        anchorOnly: true,
                        policyMode: .basicX509
                    )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw transportFailure(
                error,
                endpoint: endpoint,
                delivery: "buffered"
            )
        }

        guard let response = response as? HTTPURLResponse else {
            throw OllamaAdapterError.invalidHTTPResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            throw OllamaAdapterError.httpStatus(
                response.statusCode
            )
        }

        return try JSONDecoder().decode(
            OllamaChatChunk.self,
            from: data
        )
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

                    do {
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
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        throw transportFailure(
                            error,
                            endpoint: endpoint,
                            delivery: "stream"
                        )
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

private extension OllamaURLSessionRuntime {
    func transportFailure(
        _ error: Error,
        endpoint: URL,
        delivery: String
    ) -> NSError {
        let underlying = error as NSError
        let endpointValue = endpoint.absoluteString
        let trustValue = trust.diagnosticName

        return NSError(
            domain: underlying.domain,
            code: underlying.code,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Ollama \(delivery) invocation to '\(endpointValue)' using \(trustValue) trust failed: \(error.localizedDescription)",
                NSUnderlyingErrorKey: underlying,
                "agentic_provider": "ollama",
                "agentic_endpoint": endpointValue,
                "agentic_trust": trustValue,
                "agentic_delivery": delivery,
            ]
        )
    }
}
