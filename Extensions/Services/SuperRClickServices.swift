import Foundation

public enum SuperRClickServiceKind: String, CaseIterable, Codable, Sendable {
    case transformText
    case processFiles
    case runWorkflow
}

public struct SuperRClickServiceRequest: Codable, Equatable, Sendable {
    public var kind: SuperRClickServiceKind
    public var text: String?
    public var fileURLs: [URL]
    public var metadata: [String: String]

    public init(
        kind: SuperRClickServiceKind,
        text: String? = nil,
        fileURLs: [URL] = [],
        metadata: [String: String] = [:]
    ) {
        self.kind = kind
        self.text = text
        self.fileURLs = fileURLs
        self.metadata = metadata
    }
}

public struct SuperRClickServiceResponse: Codable, Equatable, Sendable {
    public var outputText: String?
    public var shouldReplaceSelection: Bool
    public var notes: [String]

    public init(
        outputText: String? = nil,
        shouldReplaceSelection: Bool = false,
        notes: [String] = []
    ) {
        self.outputText = outputText
        self.shouldReplaceSelection = shouldReplaceSelection
        self.notes = notes
    }
}

public protocol SuperRClickServiceHandling {
    func handle(_ request: SuperRClickServiceRequest) async throws -> SuperRClickServiceResponse
}

public actor SuperRClickServicesEngine: SuperRClickServiceHandling {
    public init() {}

    public func handle(_ request: SuperRClickServiceRequest) async throws -> SuperRClickServiceResponse {
        switch request.kind {
        case .transformText:
            return SuperRClickServiceResponse(
                outputText: request.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                shouldReplaceSelection: true,
                notes: ["Text transform placeholder"]
            )
        case .processFiles:
            return SuperRClickServiceResponse(
                notes: ["File processing placeholder for \(request.fileURLs.count) item(s)"]
            )
        case .runWorkflow:
            return SuperRClickServiceResponse(
                notes: ["Workflow placeholder"]
            )
        }
    }
}

public final class SuperRClickServicesProvider {
    private let engine: SuperRClickServicesEngine

    public init(engine: SuperRClickServicesEngine = SuperRClickServicesEngine()) {
        self.engine = engine
    }

    public func handleTextService(_ text: String) async throws -> SuperRClickServiceResponse {
        try await engine.handle(
            SuperRClickServiceRequest(kind: .transformText, text: text)
        )
    }

    public func handleFileService(_ fileURLs: [URL]) async throws -> SuperRClickServiceResponse {
        try await engine.handle(
            SuperRClickServiceRequest(kind: .processFiles, fileURLs: fileURLs)
        )
    }

    public func handleWorkflowService(name: String) async throws -> SuperRClickServiceResponse {
        try await engine.handle(
            SuperRClickServiceRequest(kind: .runWorkflow, metadata: ["name": name])
        )
    }
}
