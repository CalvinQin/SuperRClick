import Foundation

public enum LLMProviderType: String, Codable, CaseIterable, Sendable {
    case openaiCompatible
    case anthropic
    case google
    case custom
}

public struct LLMProviderPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let type: LLMProviderType
    public let name: String
    public let baseURL: String
    public let defaultModel: String
    public let models: [String]
    public let iconName: String
    public let logoDomain: String?
    
    public init(id: String, type: LLMProviderType, name: String, baseURL: String, defaultModel: String, models: [String], iconName: String, logoDomain: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.models = models
        self.iconName = iconName
        self.logoDomain = logoDomain
    }
    
    // MARK: - Provider Presets (verified against official docs 2026-03-31)
    
    public static let all: [LLMProviderPreset] = [
        // ── DeepSeek ─────────────────────────────────────────────
        // https://api-docs.deepseek.com
        // V3.2 behind deepseek-chat, R1 behind deepseek-reasoner
        LLMProviderPreset(
            id: "deepseek",
            type: .openaiCompatible,
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            defaultModel: "deepseek-chat",
            models: [
                "deepseek-chat",
                "deepseek-reasoner"
            ],
            iconName: "brain.head.profile",
            logoDomain: "deepseek.com"
        ),
        // ── OpenAI ───────────────────────────────────────────────
        // https://platform.openai.com/docs/models
        // GPT-5.4 family (nano/mini/full); gpt-4o kept as legacy fallback
        LLMProviderPreset(
            id: "openai",
            type: .openaiCompatible,
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            defaultModel: "gpt-4o",
            models: [
                "gpt-4o",
                "gpt-4o-mini",
                "gpt-5.4-nano",
                "gpt-5.4-mini",
                "gpt-5.4"
            ],
            iconName: "sparkles",
            logoDomain: "openai.com"
        ),
        // ── Anthropic Claude ─────────────────────────────────────
        // https://docs.anthropic.com/en/docs/about-claude/models
        // Haiku 4.5, Sonnet 4.6, Opus 4.6 are current production models
        LLMProviderPreset(
            id: "anthropic",
            type: .anthropic,
            name: "Anthropic Claude",
            baseURL: "https://api.anthropic.com/v1",
            defaultModel: "claude-sonnet-4-6-20260217",
            models: [
                "claude-haiku-4-5-20250512",
                "claude-sonnet-4-6-20260217",
                "claude-opus-4-6-20260205"
            ],
            iconName: "cpu",
            logoDomain: "anthropic.com"
        ),
        // ── Google Gemini ────────────────────────────────────────
        // https://ai.google.dev/gemini-api/docs/models
        // 2.5 Flash/Pro are stable; 3.x are preview
        LLMProviderPreset(
            id: "google",
            type: .google,
            name: "Google Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            defaultModel: "gemini-2.5-flash",
            models: [
                "gemini-2.5-flash",
                "gemini-2.5-pro",
                "gemini-3-flash-preview",
                "gemini-3.1-pro-preview"
            ],
            iconName: "star.fill",
            logoDomain: "google.com"
        ),
        // ── 智谱 GLM ────────────────────────────────────────────
        // https://bigmodel.cn/dev/api/normal-model/glm-5
        // GLM-5 flagship, GLM-4 series mature, Z1 for reasoning
        LLMProviderPreset(
            id: "zhipu",
            type: .openaiCompatible,
            name: "智谱 GLM",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            defaultModel: "glm-4-flash",
            models: [
                "glm-4-flash",
                "glm-4-plus",
                "glm-5",
                "glm-z1-air",
                "glm-z1-airx"
            ],
            iconName: "cube.transparent",
            logoDomain: "zhipuai.cn"
        ),
        // ── 通义千问 (Qwen) ──────────────────────────────────────
        // https://help.aliyun.com/zh/model-studio/getting-started/models
        // Commercial: qwen3-max / qwen-plus (升级至3.5) / qwen-turbo
        // Qwen3.5-Plus & Flash are new additions
        LLMProviderPreset(
            id: "qwen",
            type: .openaiCompatible,
            name: "通义千问 (Qwen)",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            defaultModel: "qwen-plus",
            models: [
                "qwen-turbo",
                "qwen-plus",
                "qwen3-max",
                "qwen3.5-plus",
                "qwen3.5-flash"
            ],
            iconName: "cloud.fill",
            logoDomain: "aliyun.com"
        ),
        // ── Moonshot (Kimi) ──────────────────────────────────────
        // https://platform.moonshot.cn/docs/api/chat
        // Kimi K2.5 (multimodal) & K2 (text reasoning)
        LLMProviderPreset(
            id: "moonshot",
            type: .openaiCompatible,
            name: "Moonshot (Kimi)",
            baseURL: "https://api.moonshot.cn/v1",
            defaultModel: "kimi-k2.5",
            models: [
                "kimi-k2.5",
                "kimi-k2"
            ],
            iconName: "moon.stars.fill",
            logoDomain: "moonshot.cn"
        ),
        // ── Ollama (Local) ───────────────────────────────────────
        // https://ollama.com/library
        // Popular local models as of 2026-03
        LLMProviderPreset(
            id: "ollama",
            type: .openaiCompatible,
            name: "Ollama (本地)",
            baseURL: "http://localhost:11434/v1",
            defaultModel: "qwen3",
            models: [
                "qwen3",
                "llama4",
                "deepseek-r1",
                "glm-5",
                "mistral"
            ],
            iconName: "server.rack",
            logoDomain: "ollama.com"
        ),
        // ── Custom ───────────────────────────────────────────────
        LLMProviderPreset(
            id: "custom",
            type: .custom,
            name: "自定义 (OpenAI 兼容)",
            baseURL: "https://api.example.com/v1",
            defaultModel: "",
            models: [],
            iconName: "gearshape.2",
            logoDomain: "github.com"
        )
    ]
    
    public static func preset(for id: String) -> LLMProviderPreset? {
        all.first { $0.id == id }
    }
}
