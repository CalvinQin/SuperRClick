import Observation
import Shared
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @StateObject private var appModeManager = AppModeManager.shared
    @StateObject private var githubUpdater = GitHubUpdater.shared
    @State private var languageManager = LanguageManager.shared

    var body: some View {
        Form {
            aboutSection
            generalPreferencesSection
            
            AISettingsView(config: $coordinator.persistenceState.aiConfig) {
                coordinator.saveAIConfig()
            }
            
            actionVisibilitySection
            dangerZone
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden) // Allow parent background to shine through
        .navigationTitle(L("偏好设置", "Preferences"))
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
                    Label(L("语言设定 / Language", "Language"), systemImage: "globe")
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
                    Label(L("在 Dock 栏显示应用图标", "Show app icon in Dock"), systemImage: "dock.rectangle")
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
                    Label(L("应用更新", "App Updates"), systemImage: "arrow.down.app")
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
                Label(L("启动与向导", "Setup & Wizard"), systemImage: "wand.and.stars")
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
            Text(L("管理哪些内置动作会显示在 Finder 右键菜单中。", "Manage which built-in actions appear in the Finder context menu."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(coordinator.allDefinitions) { action in
                HStack(spacing: 12) {
                    Image(systemName: action.systemImageName ?? "bolt.fill")
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.body)
                        if let sub = action.subtitle {
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { !coordinator.isActionHidden(action) },
                        set: { isVisible in
                            coordinator.setActionHidden(action, isHidden: !isVisible)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
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
                    coordinator.clearHistory()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(L("数据管理", "Data Management"))
        }
    }
}
