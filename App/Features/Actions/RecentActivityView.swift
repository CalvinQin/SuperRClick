import Observation
import Shared
import SwiftUI

struct RecentActivityView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if coordinator.recentHistory.isEmpty {
                    emptyState
                } else {
                    recentList
                }
            }
            .padding(28)
            .padding(.top, 8)
        }
        .navigationTitle(L("最近使用", "Recent"))
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("执行记录", "Activity Log"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                
                if coordinator.recentHistory.count > 0 {
                    Button {
                        coordinator.clearHistory()
                    } label: {
                        Label(L("清除", "Clear"), systemImage: "trash")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            ForEach(coordinator.recentHistory.prefix(30)) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: ActionInvocationRecord) -> some View {
        RecordRowView(
            title: actionTitle(for: record.actionID),
            detail: record.note ?? record.context.selectedTextPreview ?? record.context.itemPaths.first ?? L("无附加详情", "No details"),
            outcome: record.outcome,
            date: record.occurredAt
        )
    }

    private func actionTitle(for id: ActionID) -> String {
        BuiltInActionCatalog.definition(for: id)?.title ?? id.rawValue
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 88, height: 88)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 6) {
                Text(L("还没有执行记录", "No activity yet"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L("执行任何动作后，详细的日志记录会出现在这里。", "Detailed logs will appear here after running any action."))
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

// MARK: - Record Row Component

private struct RecordRowView: View {
    let title: String
    let detail: String
    let outcome: InvocationOutcome
    let date: Date
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            outcomeIcon
                .frame(width: 36, height: 36)
                .background(outcomeColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(outcomeDisplayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(outcomeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(outcomeColor.opacity(0.1), in: Capsule())

                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.05 : 0.025), radius: isHovered ? 5 : 2, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var outcomeIcon: some View {
        Image(systemName: outcomeIconName)
            .font(.callout.weight(.medium))
            .foregroundStyle(outcomeColor)
    }

    private var outcomeIconName: String {
        switch outcome {
        case .success: "checkmark.seal.fill"
        case .blocked: "exclamationmark.shield.fill"
        case .failure: "xmark.octagon.fill"
        case .missingHandler: "questionmark.folder.fill"
        }
    }

    private var outcomeColor: Color {
        switch outcome {
        case .success: .green
        case .blocked: .orange
        case .failure: .red
        case .missingHandler: .purple
        }
    }

    private var outcomeDisplayName: String {
        switch outcome {
        case .success: L("成功", "Success")
        case .blocked: L("拦截", "Blocked")
        case .failure: L("失败", "Failed")
        case .missingHandler: L("未知", "Unknown")
        }
    }
}
