import Observation
import Shared
import SwiftUI

struct WorkspaceSettingsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                globalStatusSection
                workspaceProfilesSection
            }
            .padding(24)
            .padding(.top, 10)
        }
        .navigationTitle(L("工作区", "Workspaces"))
    }

    // MARK: - Global Status

    private var globalStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("全局覆盖模式", "Global Coverage Mode"), systemImage: "globe.europe.africa.fill")
                .font(.title3.weight(.bold))

            Text(L("Super RClick 已自动覆盖整个用户目录，所有 Finder 窗口中均可使用右键菜单，无需手动配置。", "Super RClick automatically covers your entire user directory. Context menus are available in all Finder windows."))
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statusChip(
                    name: L("桌面", "Desktop"),
                    icon: "desktopcomputer",
                    note: L("部分同步目录需桌面增强", "Some synced folders need Desktop Enhancement")
                )
                statusChip(
                    name: L("文稿", "Documents"),
                    icon: "doc.text.fill",
                    note: L("部分同步目录需桌面增强", "Some synced folders need Desktop Enhancement")
                )
                statusChip(
                    name: L("下载", "Downloads"),
                    icon: "arrow.down.circle.fill",
                    note: L("已全局覆盖", "Globally covered")
                )
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(L("监控根目录：\(RealUserDirectories.homeDirectory().path)", "Root directory: \(RealUserDirectories.homeDirectory().path)"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func statusChip(name: String, icon: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            Text(name)
                .font(.headline)
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Workspace Profiles

    private var workspaceProfilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("工作区配置", "Workspace Profiles"), systemImage: "square.stack.3d.up.fill")
                .font(.title3.weight(.bold))

            if coordinator.persistenceState.workspaceProfiles.isEmpty {
                Text(L("暂未设置特定工作区规则", "No workspace-specific rules configured"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(coordinator.persistenceState.workspaceProfiles) { profile in
                    profileRow(profile)
                }
            }
        }
    }

    private func profileRow(_ profile: WorkspaceProfile) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                Text(profile.rootURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text(L("\(profile.pinnedActionIDs.count) 个固定动作 · \(profile.visibilityRuleIDs.count) 条规则", "\(profile.pinnedActionIDs.count) pinned · \(profile.visibilityRuleIDs.count) rules"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
