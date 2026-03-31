import Observation
import Shared
import SwiftUI

struct MenuBarRootView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Super RClick")
                        .font(.subheadline.weight(.semibold))
                    Text(coordinator.sampleContext.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // Quick Actions
            VStack(alignment: .leading, spacing: 2) {
                menuButton(
                    title: L("批量重命名", "Batch Rename"),
                    icon: "pencil.and.list.clipboard"
                ) {
                    coordinator.openBatchRename()
                }

                menuButton(
                    title: L("压缩文件", "Compress Files"),
                    icon: "archivebox"
                ) {
                    coordinator.runCompressFromToolbox()
                }

                menuButton(
                    title: L("图片转换", "Convert Image"),
                    icon: "photo.on.rectangle.angled"
                ) {
                    coordinator.runImageConversionFromToolbox()
                }

                menuButton(
                    title: L("快速跳转目录", "Quick Jump to Directory"),
                    icon: "arrow.right.circle"
                ) {
                    coordinator.quickJumpToDirectory()
                }

                menuButton(
                    title: L("在终端打开", "Open Terminal"),
                    icon: "terminal"
                ) {
                    coordinator.runOpenTerminalFromToolbox()
                }
            }
            .padding(.vertical, 4)

            // Footer
            HStack {
                Button(L("偏好设置...", "Preferences...")) {
                    openMainWindow()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))

                Spacer()
                
                Button(L("退出", "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(BatchRenamePanelHost(coordinator: coordinator))
    }

    private func menuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .symbolRenderingMode(.monochrome)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 14)
    }
    
    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Try to find and show an existing main window (not MenuBarExtra panels)
        let mainWindow = NSApp.windows.first { window in
            // Exclude MenuBarExtra status item windows and panels
            !(window is NSPanel)
            && window.className != "NSStatusBarWindow"
            && !window.className.contains("MenuBarExtra")
            && window.level == .normal
        }

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // No existing window found — reopen the app to trigger WindowGroup
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "") {
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
}
