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

            // Main Actions
            VStack(alignment: .leading, spacing: 2) {
                if coordinator.pinnedActions.isEmpty {
                    Text(L("暂无固定动作", "No pinned actions"))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                } else {
                    ForEach(coordinator.pinnedActions.prefix(5)) { action in
                        Button {
                            coordinator.run(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImageName ?? "bolt.fill")
                                .symbolRenderingMode(.monochrome)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 14)
                    }
                }
                
                Divider().padding(.vertical, 2)

                Button {
                    coordinator.openBatchRename()
                } label: {
                    Label(L("批量重命名", "Batch Rename"), systemImage: "pencil.and.list.clipboard")
                        .symbolRenderingMode(.monochrome)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .padding(.horizontal, 14)
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
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(BatchRenamePanelHost(coordinator: coordinator))
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
