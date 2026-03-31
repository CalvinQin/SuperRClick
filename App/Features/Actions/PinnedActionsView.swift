import Observation
import Shared
import SwiftUI

struct PinnedActionsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if coordinator.pinnedActions.isEmpty {
                    emptyState
                } else {
                    pinnedList
                }
            }
            .padding(28)
            .padding(.top, 8)
        }
        .navigationTitle(L("已固定", "Pinned"))
        .toolbar {
            ToolbarItem {
                Button {
                    coordinator.openBatchRename()
                } label: {
                    Label(L("批量管理与重命名", "Batch Manage & Rename"), systemImage: "pencil.and.list.clipboard")
                }
            }
        }
    }

    private var pinnedList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(L("快速执行你收藏的动作", "Quickly run your favorite actions"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(L("\(coordinator.pinnedActions.count) 个动作", "\(coordinator.pinnedActions.count) actions"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ForEach(coordinator.pinnedActions) { action in
                pinnedRow(action)
            }
        }
    }

    private func pinnedRow(_ action: ActionDefinition) -> some View {
        PinnedRowView(
            title: action.title,
            subtitle: action.subtitle,
            systemImage: action.systemImageName ?? "bolt.fill",
            onRun: { coordinator.run(action) },
            onUnpin: { coordinator.togglePinned(action) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "pin.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(-15))
            }
            
            VStack(spacing: 6) {
                Text(L("还没有固定的动作", "No pinned actions"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L("在动作库中右键点击任意动作，选择「固定到面板」即可添加。", "Right-click any action in the library and choose \"Pin to Panel\" to add it here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Pinned Row Component

private struct PinnedRowView: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let onRun: () -> Void
    let onUnpin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onRun) {
                Label(L("执行", "Run"), systemImage: "play.fill")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.blue)

            Button(action: onUnpin) {
                Image(systemName: "pin.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(7)
            .background(Color.secondary.opacity(isHovered ? 0.15 : 0.06), in: Circle())
            .help(L("取消固定", "Unpin"))
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.06 : 0.025), radius: isHovered ? 6 : 3, y: 1.5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.blue.opacity(0.2) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: 0.5
                )
        )
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
