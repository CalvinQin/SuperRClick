import Observation
import Shared
import SwiftUI

struct PinnedActionsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if coordinator.pinnedActions.isEmpty {
                    emptyState
                } else {
                    pinnedList
                }
            }
            .padding(24)
            .padding(.top, 10)
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
        VStack(alignment: .leading, spacing: 14) {
            Text(L("快速执行你收藏的动作", "Quickly run your favorite actions"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            ForEach(coordinator.pinnedActions) { action in
                pinnedRow(action)
            }
        }
    }

    private func pinnedRow(_ action: ActionDefinition) -> some View {
        HStack(spacing: 16) {
            Image(systemName: action.systemImageName ?? "bolt.fill")
                .font(.title)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.headline)
                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(L("执行", "Run")) {
                coordinator.run(action)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                coordinator.togglePinned(action)
            } label: {
                Image(systemName: "pin.slash")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(Color.secondary.opacity(0.1), in: Circle())
            .help(L("取消固定", "Unpin"))
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pin.fill")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text(L("还没有固定的动作", "No pinned actions"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(L("在动作库中右键点击任意动作，选择「固定到面板」即可添加。", "Right-click any action in the library and choose \"Pin to Panel\" to add it here."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
