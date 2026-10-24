import Observation
import Shared
import SwiftUI

struct SetupCenterView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var didSeeMenu = false
    @State private var didRunAction = false

    private var canFinish: Bool {
        coordinator.finderExtensionStatus == .ready && didSeeMenu && didRunAction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("使用向导", "Setup Guide")).font(.headline)
                Spacer()
                Text(L("第 \(selectedTab + 1) / 4 步", "Step \(selectedTab + 1) of 4"))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            ProgressView(value: Double(selectedTab + 1), total: 4)
                .padding(.horizontal, 24)
                .accessibilityLabel(L("引导进度", "Setup progress"))
            Group {
                switch selectedTab {
                case 0: welcomePage
                case 1: menuCustomizationPage
                case 2: desktopBridgePage
                case 3: verificationPage
                default: welcomePage
                }
            }
            .animation(.easeInOut, value: selectedTab)
            
            Divider()
            
            HStack {
                Button(L("稍后继续", "Continue Later")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("setup.close")
                
                Spacer()
                
                if selectedTab > 0 {
                    Button(L("上一步", "Back")) {
                        selectedTab -= 1
                    }
                    .accessibilityIdentifier("setup.back")
                }
                
                if selectedTab < 3 {
                    Button(L("下一步", "Next")) {
                        selectedTab += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("setup.next")
                } else {
                    Button(L("完成向导", "Finish")) {
                        coordinator.setSetupCompleted(true)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!canFinish)
                    .accessibilityIdentifier("setup.finish")
                }
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 580)
        .onAppear {
            coordinator.refreshSetupStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.refreshSetupStatus() }
        }
    }

    private var verificationPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("确认你已经用起来", "Check that it works"))
                    .font(.title2.weight(.semibold))
                Text(L("启用开关只能证明扩展打开了。请完成下面这次实际检查，再结束向导。", "An enabled extension still needs a real menu check. Complete these steps before finishing setup."))
                    .foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(coordinator.finderExtensionDetail)
                        Button(L("重新检查扩展", "Recheck Extension")) {
                            coordinator.refreshSetupStatus()
                        }
                        .accessibilityIdentifier("setup.recheck")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                Text(L("1. 打开个人文件夹，进入一个可写目录。\n2. 在空白处右键，找到 Super RClick，尝试新建一个 TXT 文件。\n3. 看见菜单并且文件创建成功后，勾选下面两项。", "1. Open your home folder and enter a writable directory.\n2. Right-click its background, find Super RClick, and create a TXT file.\n3. Confirm both results below."))
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("在 Finder 中打开个人文件夹", "Open Home Folder in Finder")) {
                    NSWorkspace.shared.open(RealUserDirectories.homeDirectory())
                }
                .disabled(AppCoordinator.isIsolatedPreview)
                .accessibilityIdentifier("setup.openTestFolder")
                Toggle(L("我已经看到了 Super RClick 菜单", "I can see the Super RClick menu"), isOn: $didSeeMenu)
                    .accessibilityIdentifier("setup.sawMenu")
                Toggle(L("菜单动作已执行成功", "A menu action completed successfully"), isOn: $didRunAction)
                    .accessibilityIdentifier("setup.ranAction")
                Text(L("当前 Finder 覆盖个人文件夹及其子目录；这不是全磁盘访问授权。桌面空白处请使用 Option + 右键，且保持应用运行。", "Finder currently covers your home folder and its subfolders; this does not grant Full Disk Access. For the desktop background, keep the app running and use Option+right-click."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .accessibilityIdentifier("setup.verification")
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
                
                Text(L("在系统设置中启用 Finder 扩展，即可从右键菜单使用你的动作。", "Enable the Finder extension in System Settings to access your actions from the context menu."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            GroupBox {
                HStack(spacing: 16) {
                    Image(rclick: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coordinator.finderExtensionStatus == .ready
                             ? L("Finder 扩展已启用", "Finder Extension Enabled")
                             : L("Finder 扩展", "Finder Extension"))
                            .font(.headline)
                        Text(coordinator.finderExtensionDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if coordinator.finderExtensionStatus == .ready {
                        Image(rclick: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else {
                        Button(L("打开扩展设置", "Open Extension Settings")) {
                            coordinator.openFinderExtensionsSettings()
                        }
                        .disabled(AppCoordinator.isIsolatedPreview)
                        .accessibilityIdentifier("setup.openFinderExtensions")
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
                        Image(rclick: action.systemImageName ?? "bolt.fill")
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
    
    @ViewBuilder
    private var desktopBridgePage: some View {
        if AppCoordinator.isIsolatedPreview {
            ContentUnavailableView {
                RClickLabel(L("隔离预览", "Isolated Preview"), icon: "lock.shield")
            } description: {
                Text(L("此预览不会检查或请求系统权限。", "This preview does not check or request system permissions."))
            }
        } else {
            desktopBridgePermissionsPage
        }
    }

    private var desktopBridgePermissionsPage: some View {
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
                        Image(rclick: "accessibility")
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
                            Image(rclick: "checkmark.circle.fill")
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
                        Image(rclick: "keyboard")
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
                            Image(rclick: "checkmark.circle.fill")
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
