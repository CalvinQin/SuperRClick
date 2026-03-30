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
            .padding(24)
            .padding(.top, 10)
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
                Text(L("\(coordinator.recentHistory.count) 条记录", "\(coordinator.recentHistory.count) records"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
            }

            ForEach(coordinator.recentHistory.prefix(30)) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: ActionInvocationRecord) -> some View {
        HStack(spacing: 16) {
            outcomeIcon(record.outcome)
                .frame(width: 40, height: 40)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(actionTitle(for: record.actionID))
                    .font(.headline)

                Text(record.note ?? record.context.selectedTextPreview ?? record.context.itemPaths.first ?? L("无附加详情", "No details"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                outcomeBadge(record.outcome)

                Text(record.occurredAt, style: .relative)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func outcomeIcon(_ outcome: InvocationOutcome) -> some View {
        let (icon, color) = outcomeStyle(outcome)
        return Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)
    }

    private func outcomeBadge(_ outcome: InvocationOutcome) -> some View {
        let (_, color) = outcomeStyle(outcome)
        return Text(outcomeDisplayName(outcome))
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func outcomeStyle(_ outcome: InvocationOutcome) -> (String, Color) {
        switch outcome {
        case .success: ("checkmark.seal.fill", .green)
        case .blocked: ("exclamationmark.shield.fill", .orange)
        case .failure: ("xmark.octagon.fill", .red)
        case .missingHandler: ("questionmark.folder.fill", .purple)
        }
    }

    private func outcomeDisplayName(_ outcome: InvocationOutcome) -> String {
        switch outcome {
        case .success: L("执行成功", "Success")
        case .blocked: L("已被拦截", "Blocked")
        case .failure: L("执行失败", "Failed")
        case .missingHandler: L("未知处理", "Unknown")
        }
    }

    private func actionTitle(for id: ActionID) -> String {
        BuiltInActionCatalog.definition(for: id)?.title ?? id.rawValue
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text(L("还没有执行记录", "No activity yet"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(L("执行任何动作后，详细的日志记录会出现在这里。", "Detailed logs will appear here after running any action."))
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
