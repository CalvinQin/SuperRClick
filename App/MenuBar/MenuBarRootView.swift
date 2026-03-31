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
        if AppModeManager.shared.showInDock {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        if let window = NSApp.windows.first(where: { $0.title.contains("Super RClick") || $0.isKeyWindow }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
