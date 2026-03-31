import Foundation

public protocol LLMServiceProtocol: Sendable {
    var config: AIConfig { get }
    func sendMessage(prompt: String, systemPrompt: String?) async throws -> String
    func testConnection() async throws -> Bool
}

public enum LLMError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case missingAPIKey
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .invalidResponse: return "Invalid response from API."
        case .apiError(let msg): return "API Error: \(msg)"
        case .missingAPIKey: return "API Key is missing or invalid."
        }
    }
}

// MARK: - OpenAI Compatible Service
public final class OpenAICompatibleService: LLMServiceProtocol {
    public let config: AIConfig
    
    public init(config: AIConfig) {
        self.config = config
    }
    
    public func testConnection() async throws -> Bool {
        _ = try await sendMessage(prompt: "Hello", systemPrompt: nil)
        return true
    }
    
    public func sendMessage(prompt: String, systemPrompt: String?) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        guard let customApiKey = try? AIKeychainStore.load(for: config.providerID), !customApiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }
        
        var messages: [[String: String]] = []
        if let sp = systemPrompt {
            messages.append(["role": "system", "content": sp])
        }
        messages.append(["role": "user", "content": prompt])
        
        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(customApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let r = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        if r.statusCode != 200 {
            if let errResp = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw LLMError.apiError(errResp.error.message)
            }
            throw LLMError.apiError("HTTP status \(r.statusCode)")
        }
        
        let completion = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        
        return content
    }
    
    private struct OpenAIErrorResponse: Decodable {
        struct APIError: Decodable { let message: String }
        let error: APIError
    }
    
    private struct OpenAICompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}

// MARK: - Anthropic Service
public final class AnthropicService: LLMServiceProtocol {
    public let config: AIConfig
    
    public init(config: AIConfig) {
        self.config = config
    }
    
    public func testConnection() async throws -> Bool {
        _ = try await sendMessage(prompt: "Hello", systemPrompt: nil)
        return true
    }
    
    public func sendMessage(prompt: String, systemPrompt: String?) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/messages") else { throw LLMError.invalidURL }
        
        guard let customApiKey = try? AIKeychainStore.load(for: config.providerID), !customApiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }
        
        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        if let sp = systemPrompt {
            body["system"] = sp
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(customApiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let r = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        if r.statusCode != 200 {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = errDict["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw LLMError.apiError(msg)
            }
            throw LLMError.apiError("HTTP status \(r.statusCode)")
        }
        
        let completion = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let content = completion.content.first?.text else { throw LLMError.invalidResponse }
        return content
    }
    
    private struct AnthropicResponse: Decodable {
        struct Content: Decodable { let text: String }
        let content: [Content]
    }
}

// MARK: - Google Gemini Service
public final class GoogleGeminiService: LLMServiceProtocol {
    public let config: AIConfig
    
    public init(config: AIConfig) {
        self.config = config
    }
    
    public func testConnection() async throws -> Bool {
        _ = try await sendMessage(prompt: "Hello", systemPrompt: nil)
        return true
    }
    
    public func sendMessage(prompt: String, systemPrompt: String?) async throws -> String {
        guard let customApiKey = try? AIKeychainStore.load(for: config.providerID), !customApiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }
        
        guard let url = URL(string: "\(config.baseURL)/models/\(config.model):generateContent?key=\(customApiKey)") else {
            throw LLMError.invalidURL
        }
        
        var body: [String: Any] = [
            "contents": [
                ["parts": [ ["text": prompt] ]]
            ]
        ]
        
        if let sp = systemPrompt {
            body["systemInstruction"] = [
                "parts": [ ["text": sp] ]
            ]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let r = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        if r.statusCode != 200 {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = errDict["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw LLMError.apiError(msg)
            }
            throw LLMError.apiError("HTTP status \(r.statusCode)")
        }
        
        let completion = try JSONDecoder().decode(GoogleResponse.self, from: data)
        guard let text = completion.candidates.first?.content.parts.first?.text else {
            throw LLMError.invalidResponse
        }
        
        return text
    }
    
    private struct GoogleResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
    }
}

// MARK: - Factory
public enum LLMServiceFactory {
    public static func makeService(for config: AIConfig) -> LLMServiceProtocol? {
        guard config.isEnabled, !config.baseURL.isEmpty else { return nil }
        
        switch config.providerType {
        case .openaiCompatible, .custom:
            return OpenAICompatibleService(config: config)
        case .anthropic:
            return AnthropicService(config: config)
        case .google:
            return GoogleGeminiService(config: config)
        }
    }
}
