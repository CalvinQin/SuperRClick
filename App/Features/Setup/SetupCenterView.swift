import Observation
import Shared
import SwiftUI

struct SetupCenterView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: welcomePage
                case 1: menuCustomizationPage
                case 2: desktopBridgePage
                default: welcomePage
                }
            }
            .animation(.easeInOut, value: selectedTab)
            
            Divider()
            
            HStack {
                Button(L("关闭", "Close")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                if selectedTab > 0 {
                    Button(L("上一步", "Back")) {
                        selectedTab -= 1
                    }
                }
                
                if selectedTab < 2 {
                    Button(L("下一步", "Next")) {
                        selectedTab += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(L("完成向导", "Finish")) {
                        coordinator.setSetupCompleted(true)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 480)
        .onAppear {
            coordinator.refreshSetupStatus()
        }
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 30) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text(L("欢迎使用 Super RClick", "Welcome to Super RClick"))
                    .font(.largeTitle.weight(.semibold))
                
                Text(L("要使用该应用，请先在系统偏好设置中开启 Finder 扩展功能。", "To use this app, please enable the Finder extension in System Preferences."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            GroupBox {
                HStack(spacing: 16) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Finder 扩展已启用", "Finder Extension Enabled"))
                            .font(.headline)
                        Text(coordinator.finderExtensionDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if coordinator.finderExtensionStatus == .ready {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else {
                        Button(L("打开扩展设置", "Open Extension Settings")) {
                            coordinator.openFinderExtensionsSettings()
                        }
                    }
                }
                .padding(8)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var menuCustomizationPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("自定义菜单内容", "Customize Menu Content"))
                    .font(.title2.weight(.semibold))
                Text(L("只保留你真正常用的内置动作，隐藏多余选项。", "Keep only the built-in actions you actually use, hide the rest."))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)
            
            List {
                ForEach(coordinator.allDefinitions) { action in
                    HStack {
                        Image(systemName: action.systemImageName ?? "bolt.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(action.title)
                                .font(.body)
                            if let subtitle = action.subtitle {
                                Text(subtitle)
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
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
    
    private var desktopBridgePage: some View {
        let bridgeManager = DesktopBridgeManager.shared
        
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("配置桌面增强 (可选)", "Desktop Enhancement (Optional)"))
                    .font(.title2.weight(.semibold))
                Text(L("开启以下系统权限后，可以在桌面空白处按住 Option + 右键呼出增强菜单。", "Grant these permissions to use Option+Right-click on desktop for the enhanced menu."))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)
            
            VStack(spacing: 16) {
                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: "accessibility")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("辅助功能", "Accessibility"))
                                .font(.headline)
                            Text(L("帮助应用识别桌面操作范围", "Helps the app detect desktop interaction areas"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if bridgeManager.isAccessibilityEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        } else {
                            Button(L("去授权", "Grant Access")) {
                                bridgeManager.requestAccessibility()
                                coordinator.openAccessibilitySettings()
                            }
                        }
                    }
                    .padding(8)
                }
                
                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: "keyboard")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("输入监控", "Input Monitoring"))
                                .font(.headline)
                            Text(L("监听 Option 键修饰的右键点击事件", "Listen for Option-modified right-click events"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if bridgeManager.isInputMonitoringEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        } else {
                            Button(L("去授权", "Grant Access")) {
                                bridgeManager.requestInputMonitoring()
                                coordinator.openInputMonitoringSettings()
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}
