import AWSConnector

public enum BedrockModelHandleKind: String, Sendable, Codable, Hashable, CaseIterable {
    case foundation_model
    case system_inference_profile
    case application_inference_profile
    case inference_profile
}

public struct BedrockModelHandle: Sendable, Codable, Hashable, Identifiable {
    public var id: String {
        invokeIdentifier
    }

    public var invokeIdentifier: String
    public var kind: BedrockModelHandleKind
    public var region: String
    public var title: String?
    public var provider: String?
    public var sourceModelIdentifiers: [String]
    public var sourceModelArns: [String]
    public var inputModalities: [String]
    public var outputModalities: [String]
    public var streaming: Bool?
    public var status: String?
    public var type: String?

    public init(
        invokeIdentifier: String,
        kind: BedrockModelHandleKind,
        region: String,
        title: String? = nil,
        provider: String? = nil,
        sourceModelIdentifiers: [String] = [],
        sourceModelArns: [String] = [],
        inputModalities: [String] = [],
        outputModalities: [String] = [],
        streaming: Bool? = nil,
        status: String? = nil,
        type: String? = nil
    ) {
        self.invokeIdentifier = invokeIdentifier
        self.kind = kind
        self.region = region
        self.title = title
        self.provider = provider
        self.sourceModelIdentifiers = sourceModelIdentifiers
        self.sourceModelArns = sourceModelArns
        self.inputModalities = inputModalities
        self.outputModalities = outputModalities
        self.streaming = streaming
        self.status = status
        self.type = type
    }
}

public extension BedrockModelHandle {
    init(
        model: Bedrock.Models.Summary,
        region: String
    ) {
        self.init(
            invokeIdentifier: model.modelId,
            kind: .foundation_model,
            region: region,
            title: model.modelName ?? model.modelId,
            provider: model.providerName,
            sourceModelIdentifiers: [
                model.modelId
            ],
            sourceModelArns: [
                model.modelArn
            ],
            inputModalities: model.inputModalities ?? [],
            outputModalities: model.outputModalities ?? [],
            streaming: model.responseStreamingSupported,
            status: model.modelLifecycle?.status,
            type: nil
        )
    }

    init(
        profile: Bedrock.InferenceProfiles.Summary,
        region: String
    ) {
        let modelArns = profile.models.map(\.modelArn)

        self.init(
            invokeIdentifier: profile.inferenceProfileId,
            kind: Self.kind(
                profileType: profile.type
            ),
            region: region,
            title: profile.inferenceProfileName,
            provider: nil,
            sourceModelIdentifiers: modelArns.map {
                Self.modelIdentifier(
                    fromArn: $0
                )
            },
            sourceModelArns: modelArns,
            inputModalities: [],
            outputModalities: [],
            streaming: nil,
            status: profile.status,
            type: profile.type
        )
    }

    init(
        profile: Bedrock.InferenceProfiles.Profile,
        region: String
    ) {
        let modelArns = profile.models.map(\.modelArn)

        self.init(
            invokeIdentifier: profile.inferenceProfileId,
            kind: Self.kind(
                profileType: profile.type
            ),
            region: region,
            title: profile.inferenceProfileName,
            provider: nil,
            sourceModelIdentifiers: modelArns.map {
                Self.modelIdentifier(
                    fromArn: $0
                )
            },
            sourceModelArns: modelArns,
            inputModalities: [],
            outputModalities: [],
            streaming: nil,
            status: profile.status,
            type: profile.type
        )
    }

    func metadata(
        merging values: [String: String] = [:]
    ) -> [String: String] {
        var metadata = values

        metadata["provider"] = metadata["provider"] ?? "aws"
        metadata["adapter"] = metadata["adapter"] ?? "bedrock_converse"
        metadata["bedrock_region"] = region
        metadata["bedrock_handle_kind"] = kind.rawValue
        metadata["bedrock_invoke_identifier"] = invokeIdentifier

        if let title {
            metadata["bedrock_title"] = title
        }

        if let provider {
            metadata["bedrock_provider"] = provider
        }

        if let status {
            metadata["bedrock_status"] = status
        }

        if let type {
            metadata["bedrock_type"] = type
        }

        if !sourceModelIdentifiers.isEmpty {
            metadata["bedrock_source_models"] = sourceModelIdentifiers.joined(
                separator: ","
            )
        }

        if !sourceModelArns.isEmpty {
            metadata["bedrock_source_model_arns"] = sourceModelArns.joined(
                separator: ","
            )
        }

        return metadata
    }

    var isLegacy: Bool {
        let normalized = [
            invokeIdentifier,
            title ?? "",
            provider ?? "",
            status ?? "",
            type ?? "",
            sourceModelIdentifiers.joined(
                separator: " "
            ),
            sourceModelArns.joined(
                separator: " "
            )
        ].joined(
            separator: " "
        ).lowercased()

        return normalized.contains(
            "legacy"
        )
    }
}

private extension BedrockModelHandle {
    static func kind(
        profileType: String?
    ) -> BedrockModelHandleKind {
        switch profileType?.uppercased() {
        case "SYSTEM_DEFINED":
            return .system_inference_profile

        case "APPLICATION",
             "APPLICATION_DEFINED":
            return .application_inference_profile

        case nil:
            return .inference_profile

        default:
            return .inference_profile
        }
    }

    static func modelIdentifier(
        fromArn arn: String
    ) -> String {
        guard let last = arn.split(
            separator: "/"
        ).last else {
            return arn
        }

        return String(
            last
        )
    }
}
