import SwiftUI
import Shared

public struct AISettingsView: View {
    @State private var config: AIConfig
    private let onSave: (AIConfig) -> Bool
    @State private var apiKey: String = ""
    @State private var loadedAPIKey: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: Result<Bool, Error>?
    @State private var isSaved = false
    @State private var hasUnsavedChanges = false
    @State private var saveError: String?
    @State private var keychainSaveError: String?
    
    public init(config: AIConfig, onSave: @escaping (AIConfig) -> Bool) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }
    
    public var body: some View {
        Group {
            Section {
                Toggle(L("启用 AI 功能", "Enable AI Features"), isOn: $config.isEnabled)
                    .accessibilityIdentifier("ai.enabled")
            } header: {
                Text(L("AI 设置", "AI Settings"))
            }
            
            Section {
                Picker(L("服务商", "Provider"), selection: $config.providerID) {
                    ForEach(LLMProviderPreset.all) { preset in
                        HStack {
                            Image(rclick: preset.iconName)
                                .resizable().frame(width: 16, height: 16)
                                .accessibilityHidden(true)
                            Text(preset.name)
                        }
                        .tag(preset.id)
                    }
                }
                .onChange(of: config.providerID) { _, newValue in
                    loadAPIKey()
                    if let preset = LLMProviderPreset.preset(for: newValue) {
                        config.providerType = preset.type
                        config.providerName = preset.name
                        config.baseURL = preset.baseURL
                        config.model = preset.defaultModel
                    }
                    markUnsaved()
                }
                
                if config.providerID == "custom" {
                    TextField(L("Base URL", "Base URL"), text: $config.baseURL)
                        .onChange(of: config.baseURL) { _, _ in markUnsaved() }
                    TextField(L("模型名称", "Model Name"), text: $config.model)
                        .onChange(of: config.model) { _, _ in markUnsaved() }
                } else if let preset = LLMProviderPreset.preset(for: config.providerID) {
                    if preset.models.isEmpty {
                        TextField(L("模型名称", "Model Name"), text: $config.model)
                            .onChange(of: config.model) { _, _ in markUnsaved() }
                    } else {
                        let allModels = preset.models.contains(config.model)
                            ? preset.models
                            : [config.model] + preset.models
                        Picker(L("模型", "Model"), selection: $config.model) {
                            ForEach(allModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .onChange(of: config.model) { _, _ in markUnsaved() }
                    }
                }
                
                SecureField(L("API Key", "API Key"), text: $apiKey)
                    .onChange(of: apiKey) { _, newValue in
                        guard newValue != loadedAPIKey else {
                            keychainSaveError = nil
                            return
                        }
                        markUnsaved()
                        persistAPIKeyIfNeeded()
                    }
                
                if config.providerID == "ollama" {
                    Text(L("注意: Ollama 需要在本地运行并且无需 API Key。", "Note: Ollama requires local instance and doesn't need an API Key."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(L("LLM 配置", "LLM Configuration"))
            } footer: {
                Text(L("API Key 将被安全地存储在 macOS 钥匙串中。", "API Key is securely stored in macOS Keychain."))
            }
            .disabled(!config.isEnabled)
            
            Section {
                HStack {
                    Button {
                        saveSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Image(rclick: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            Text(isSaved ? L("已保存", "Saved") : L("保存设置", "Save Settings"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isSaved ? .green : .accentColor)
                    .accessibilityIdentifier("ai.save")
                    
                    Spacer()
                    
                    Button(L("测试连接", "Test Connection")) {
                        Task { await testConnection() }
                    }
                    .disabled(isTestingConnection || !config.isEnabled || isIsolatedUISession)
                    .accessibilityIdentifier("ai.testConnection")
                    
                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 8)
                    } else if let result = testResult {
                        switch result {
                        case .success:
                            Image(rclick: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L("连接成功", "Connection Successful"))
                                .foregroundColor(.green)
                        case .failure(let error):
                            Image(rclick: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }

                if let error = keychainSaveError ?? saveError {
                    RClickLabel(error, icon: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("ai.saveError")
                } else if hasUnsavedChanges {
                    Text(L("有未保存的设置。", "You have unsaved settings."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ai.unsavedChanges")
                }
            }
            
            Section {
                Text(L("注：OCR 文字提取和背景移除功能依赖 macOS 本地 Vision 框架，无需配置 API Key 即可使用。", "Note: OCR and Background Removal rely on macOS local Vision framework and work without API Key."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        .onAppear {
            loadAPIKey()
        }
        .onChange(of: config.isEnabled) { _, _ in markUnsaved() }
    }
    
    private func markUnsaved() {
        isSaved = false
        hasUnsavedChanges = true
        saveError = nil
    }
    
    @discardableResult
    private func saveSettings() -> Bool {
        guard persistAPIKeyIfNeeded(), onSave(config) else {
            isSaved = false
            hasUnsavedChanges = true
            saveError = L("设置未能保存。请重试；当前更改仍保留在此页面。", "Settings could not be saved. Please try again; your changes are still on this page.")
            return false
        }

        saveError = nil
        hasUnsavedChanges = false
        withAnimation(.easeInOut(duration: 0.3)) {
            isSaved = true
        }
        return true
    }
    
    private func loadAPIKey() {
        let key: String
        if isIsolatedUISession {
            key = ""
        } else {
            key = (try? AIKeychainStore.load(for: config.providerID)) ?? ""
        }
        // Update the comparison value first so loading a provider never writes its key back.
        loadedAPIKey = key
        apiKey = key
        keychainSaveError = nil
        testResult = nil
    }

    @discardableResult
    private func persistAPIKeyIfNeeded() -> Bool {
        guard apiKey != loadedAPIKey else {
            keychainSaveError = nil
            return true
        }

        guard !isIsolatedUISession else {
            loadedAPIKey = apiKey
            return true
        }

        do {
            try AIKeychainStore.save(apiKey: apiKey, for: config.providerID)
            loadedAPIKey = apiKey
            keychainSaveError = nil
            return true
        } catch {
            keychainSaveError = L("API Key 未能保存到钥匙串：", "The API key could not be saved to Keychain: ") + error.localizedDescription
            return false
        }
    }

    private var isIsolatedUISession: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SUPERRCLICK_TEST_STORAGE"] != nil
        #else
        false
        #endif
    }
    
    private func testConnection() async {
        guard !isTestingConnection, config.isEnabled, !isIsolatedUISession else { return }
        isTestingConnection = true
        defer { isTestingConnection = false }
        testResult = nil

        // A connection check should not claim success when its settings could not be saved.
        guard saveSettings() else { return }
        
        guard let service = LLMServiceFactory.makeService(for: config) else {
            testResult = .failure(LLMError.invalidURL)
            return
        }
        
        do {
            let success = try await service.testConnection()
            testResult = .success(success)
        } catch {
            testResult = .failure(error)
        }
    }
}
