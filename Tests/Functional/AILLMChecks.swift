import Foundation
import Shared

// Every service instance injects synthetic credentials and an in-memory transport.
// These checks never call the default Keychain or URLSession dependencies.
private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw CheckFailure(description: message) }
}

private actor FakeHTTP {
    private var requests: [URLRequest] = []
    private let status: Int
    private let body: String
    private let isHTTP: Bool

    init(status: Int = 200,
         body: String = #"{"choices":[{"message":{"content":"Synthetic completion"}}]}"#,
         isHTTP: Bool = true) {
        self.status = status
        self.body = body
        self.isHTTP = isHTTP
    }

    func send(_ request: URLRequest) -> (Data, URLResponse) {
        requests.append(request)
        let url = request.url!
        let response: URLResponse = isHTTP
            ? HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            : URLResponse(url: url, mimeType: "application/json", expectedContentLength: body.utf8.count, textEncodingName: "utf-8")
        return (Data(body.utf8), response)
    }

    func recordedRequests() -> [URLRequest] { requests }
}

@main
private enum AILLMChecks {
    private struct Result: Codable {
        let name: String
        let passed: Bool
        let detail: String
    }

    static func main() async throws {
        let checks: [(String, @Sendable () async throws -> Void)] = [
            ("Ollama accepts an empty key without Authorization", { try await completion(provider: "ollama", key: "") }),
            ("Ollama accepts an absent key without Authorization", { try await completion(provider: "ollama", key: nil) }),
            ("Ollama preserves an explicitly supplied Bearer key", { try await completion(provider: "ollama", key: "synthetic-ollama-key") }),
            ("OpenAI preserves Bearer auth, request payload, and response decoding", { try await completion(provider: "openai", key: "synthetic-openai-key") }),
            ("Other providers reject empty, absent, and unavailable keys before HTTP", { try await missingKeys() }),
            ("Connection check works for keyless Ollama", { try await connection() }),
            ("Structured and unstructured HTTP errors are preserved", { try await httpErrors() }),
            ("Invalid HTTP responses and missing completion choices are rejected", { try await invalidResponses() }),
            ("Transport cancellation propagates", { try await cancellation() })
        ]
        var results: [Result] = []
        for (name, check) in checks {
            do {
                try await check()
                results.append(Result(name: name, passed: true, detail: "PASS"))
                print("PASS: \(name)")
            } catch {
                let detail = String(describing: error)
                results.append(Result(name: name, passed: false, detail: detail))
                print("FAIL: \(name): \(detail)")
            }
        }
        if let report = ProcessInfo.processInfo.environment["SUPERRCLICK_LLM_REPORT"] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(results).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
        let failures = results.filter { !$0.passed }.count
        print("\(results.count - failures)/\(results.count) checks passed; no Keychain access or network requests.")
        exit(failures == 0 ? 0 : 1)
    }

    private static func config(_ provider: String) -> AIConfig {
        AIConfig(providerID: provider, providerType: provider == "custom" ? .custom : .openaiCompatible,
                 providerName: "Synthetic provider", baseURL: "http://localhost:11434/v1",
                 model: "synthetic-model", isEnabled: true)
    }

    private static func service(_ provider: String, key: String?, http: FakeHTTP) -> OpenAICompatibleService {
        OpenAICompatibleService(config: config(provider), keyLoader: { requestedProvider in
            try require(requestedProvider == provider, "Key loaded for the wrong provider")
            return key
        }, transport: { request in await http.send(request) })
    }

    private static func completion(provider: String, key: String?) async throws {
        let http = FakeHTTP()
        let answer = try await service(provider, key: key, http: http)
            .sendMessage(prompt: "Synthetic user prompt", systemPrompt: "Synthetic system prompt")
        try require(answer == "Synthetic completion", "Completion content was not decoded")
        let requests = await http.recordedRequests()
        try require(requests.count == 1, "Expected exactly one request")
        let request = requests[0]
        let expectedAuthorization = key.flatMap { $0.isEmpty ? nil : "Bearer \($0)" }
        try require(request.value(forHTTPHeaderField: "Authorization") == expectedAuthorization, "Incorrect Authorization header")
        try require(request.httpMethod == "POST", "Expected POST")
        try require(request.url?.absoluteString == "http://localhost:11434/v1/chat/completions", "Incorrect completions endpoint")
        try require(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "Incorrect Content-Type")
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        try require(body?["model"] as? String == "synthetic-model", "Incorrect model")
        try require(body?["temperature"] as? Double == 0.7, "Temperature changed")
        let messages = body?["messages"] as? [[String: String]]
        try require(messages == [["role": "system", "content": "Synthetic system prompt"],
                                 ["role": "user", "content": "Synthetic user prompt"]], "Prompt roles or content changed")
    }

    private static func missingKeys() async throws {
        // Even a loopback URL cannot bypass the key requirement for another provider.
        for provider in ["openai", "deepseek", "zhipu", "qwen", "moonshot", "custom", "Ollama"] {
            for mode in 0..<3 {
                let http = FakeHTTP()
                let client = OpenAICompatibleService(config: config(provider), keyLoader: { _ in
                    if mode == 2 { throw CheckFailure(description: "Synthetic credential lookup failure") }
                    return mode == 0 ? "" : nil
                }, transport: { request in await http.send(request) })
                do {
                    _ = try await client.sendMessage(prompt: "Synthetic prompt", systemPrompt: nil)
                    throw CheckFailure(description: "\(provider) unexpectedly accepted missing credentials (mode \(mode))")
                } catch LLMError.missingAPIKey {
                    let requests = await http.recordedRequests()
                    try require(requests.isEmpty, "\(provider) contacted transport before rejecting missing credentials")
                }
            }
        }
    }

    private static func connection() async throws {
        let http = FakeHTTP()
        let connected = try await service("ollama", key: nil, http: http).testConnection()
        try require(connected, "Connection check did not succeed")
        let requests = await http.recordedRequests()
        try require(requests.count == 1, "Connection check should send one request")
        try require(requests[0].value(forHTTPHeaderField: "Authorization") == nil, "Keyless connection check sent Authorization")
        let body = try JSONSerialization.jsonObject(with: requests[0].httpBody ?? Data()) as? [String: Any]
        try require(body?["messages"] as? [[String: String]] == [["role": "user", "content": "Hello"]], "Connection probe changed")
    }

    private static func httpErrors() async throws {
        for (status, body, expected) in [(401, #"{"error":{"message":"Synthetic rejected key"}}"#, "Synthetic rejected key"),
                                         (503, "Synthetic service unavailable", "HTTP status 503")] {
            let http = FakeHTTP(status: status, body: body)
            do {
                _ = try await service("openai", key: "synthetic-key", http: http).sendMessage(prompt: "Test", systemPrompt: nil)
                throw CheckFailure(description: "HTTP \(status) unexpectedly succeeded")
            } catch LLMError.apiError(let message) {
                try require(message == expected, "API error detail changed")
            }
        }
    }

    private static func invalidResponses() async throws {
        for http in [FakeHTTP(isHTTP: false), FakeHTTP(body: #"{"choices":[]}"#)] {
            do {
                _ = try await service("openai", key: "synthetic-key", http: http).sendMessage(prompt: "Test", systemPrompt: nil)
                throw CheckFailure(description: "Invalid response unexpectedly succeeded")
            } catch LLMError.invalidResponse { }
        }
    }

    private static func cancellation() async throws {
        let client = OpenAICompatibleService(config: config("openai"), keyLoader: { _ in "synthetic-key" },
                                            transport: { _ in throw CancellationError() })
        do {
            _ = try await client.sendMessage(prompt: "Test", systemPrompt: nil)
            throw CheckFailure(description: "Cancelled request unexpectedly succeeded")
        } catch is CancellationError { }
    }
}
