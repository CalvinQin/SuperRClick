import SwiftUI
import Shared

public struct AISettingsView: View {
    @Binding var config: AIConfig
    var onSave: (() -> Void)?
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: Result<Bool, Error>?
    @State private var isSaved = false
    
    public init(config: Binding<AIConfig>, onSave: (() -> Void)? = nil) {
        self._config = config
        self.onSave = onSave
    }
    
    public var body: some View {
        Form {
            Section {
                Toggle(L("启用 AI 功能", "Enable AI Features"), isOn: $config.isEnabled)
            }
            
            Section {
                Picker(L("服务商", "Provider"), selection: $config.providerID) {
                    ForEach(LLMProviderPreset.all) { preset in
                        Text(preset.name).tag(preset.id)
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
                        try? AIKeychainStore.save(apiKey: newValue, for: config.providerID)
                        markUnsaved()
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
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            Text(isSaved ? L("已保存", "Saved") : L("保存设置", "Save Settings"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isSaved ? .green : .accentColor)
                    .disabled(!config.isEnabled)
                    
                    Spacer()
                    
                    Button(L("测试连接", "Test Connection")) {
                        Task { await testConnection() }
                    }
                    .disabled(isTestingConnection || !config.isEnabled)
                    
                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 8)
                    } else if let result = testResult {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L("连接成功", "Connection Successful"))
                                .foregroundColor(.green)
                        case .failure(let error):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                    }
                }
            }
            
            Section {
                Text(L("注：OCR 文字提取和背景移除功能依赖 macOS 本地 Vision 框架，无需配置 API Key 即可使用。", "Note: OCR and Background Removal rely on macOS local Vision framework and work without API Key."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadAPIKey()
        }
        .onChange(of: config.isEnabled) { _, _ in markUnsaved() }
    }
    
    private func markUnsaved() {
        isSaved = false
    }
    
    private func saveSettings() {
        onSave?()
        withAnimation(.easeInOut(duration: 0.3)) {
            isSaved = true
        }
        // Reset after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { isSaved = false }
        }
    }
    
    private func loadAPIKey() {
        if let key = try? AIKeychainStore.load(for: config.providerID) {
            apiKey = key
        } else {
            apiKey = ""
        }
        testResult = nil
    }
    
    private func testConnection() async {
        // Auto-save before testing
        saveSettings()
        
        isTestingConnection = true
        testResult = nil
        
        guard let service = LLMServiceFactory.makeService(for: config) else {
            isTestingConnection = false
            testResult = .failure(LLMError.invalidURL)
            return
        }
        
        do {
            let success = try await service.testConnection()
            testResult = .success(success)
        } catch {
            testResult = .failure(error)
        }
        
        isTestingConnection = false
    }
}
