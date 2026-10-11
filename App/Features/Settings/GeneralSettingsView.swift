import Observation
import Shared
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @StateObject private var appModeManager = AppModeManager.shared
    @StateObject private var githubUpdater = GitHubUpdater.shared
    @State private var languageManager = LanguageManager.shared
    @State private var confirmClearHistory = false

    var body: some View {
        Form {
            aboutSection
            generalPreferencesSection
            
            AISettingsView(config: coordinator.persistenceState.aiConfig) { draft in
                coordinator.saveAIConfig(draft)
            }
            
            actionVisibilitySection
            dangerZone
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden) // Allow parent background to shine through
        .navigationTitle(L("偏好设置", "Preferences"))
        .alert(L("清除全部执行记录？", "Clear all activity?"), isPresented: $confirmClearHistory) {
            Button(L("取消", "Cancel"), role: .cancel) { }
            Button(L("清除历史", "Clear History"), role: .destructive) { coordinator.clearHistory() }
        } message: {
            Text(L("此操作无法撤销，不会删除你的文件或自定义动作。", "This cannot be undone. Your files and custom actions will be kept."))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Super RClick")
                        .font(.title2.bold())
                    Text(L("版本", "Version") + " " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(L("需要 macOS 15 或更新版本", "Requires macOS 15 or later"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(L("强大的 Finder 原生右键效率平台", "A powerful native Finder context menu platform"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text(L("关于", "About"))
        }
    }

    // MARK: - General Preferences

    private var generalPreferencesSection: some View {
        Section {
            // App Language (Dynamic Switcher)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RClickLabel(L("语言设定 / Language", "Language"), icon: "globe")
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { languageManager.currentLanguage },
                        set: { newLanguage in
                            languageManager.currentLanguage = newLanguage
                            // Force refresh cached action data with new language
                            coordinator.refresh()
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L("语言", "Language"))
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                Text(L("切换语言后界面将立即更新为所选语言。", "The interface language will update immediately."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            // App Appearance / Mode
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $appModeManager.showInDock) {
                    RClickLabel(L("在 Dock 栏显示应用图标", "Show app icon in Dock"), icon: "dock.rectangle")
                }
                .toggleStyle(.switch)
                
                Text(L("关闭后，应用将只以辅助程序的形式运行在顶部状态栏（Menu Bar）。", "When disabled, the app runs as a menu bar utility only."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            // Auto Updater
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RClickLabel(L("应用更新", "App Updates"), icon: "arrow.down.app")
                    Spacer()
                    Button(L("检查更新", "Check for Updates")) {
                        githubUpdater.checkForUpdates(manual: true)
                    }
                    .disabled(githubUpdater.isChecking)
                }
                
                Text(L("从 GitHub 安全、快速地获取最新版本。", "Get the latest version from GitHub."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            // Open Setup Center
            HStack {
                RClickLabel(L("启动与向导", "Setup & Wizard"), icon: "wand.and.stars")
                Spacer()
                Button(L("打开向导中心", "Open Setup Wizard")) {
                    coordinator.presentSetupCenter()
                }
            }
            .padding(.vertical, 4)

        } header: {
            Text(L("一般设置", "General"))
        }
    }

    // MARK: - Action Visibility

    private var actionVisibilitySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("定制 Finder 右键菜单", "Customize your Finder menu"))
                    Text(L("在动作库中管理显示、固定与自定义动作。", "Manage visibility, pins, and custom actions in the library."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(L("管理动作", "Manage Actions")) { coordinator.selectedSection = .actionLibrary }
            }
        } header: {
            Text(L("动作可见性", "Action Visibility"))
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("清除执行记录", "Clear Activity Log"))
                        .font(.body)
                    Text(L("删除所有最近使用过的数据追踪", "Delete all recent usage data"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L("清除历史", "Clear History"), role: .destructive) {
                    confirmClearHistory = true
                }
                .disabled(coordinator.recentHistory.isEmpty)
            }
            .padding(.vertical, 4)
        } header: {
            Text(L("数据管理", "Data Management"))
        }
    }
}
