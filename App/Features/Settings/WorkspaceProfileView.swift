import Foundation
import Observation
import Shared
import SwiftUI

struct WorkspaceProfileView: View {
    @Bindable var coordinator: AppCoordinator
    private let onAddMonitoredFolder: (() -> Void)?
    private let onRemoveMonitoredFolder: ((URL) -> Void)?

    init(
        coordinator: AppCoordinator,
        onAddMonitoredFolder: (() -> Void)? = nil,
        onRemoveMonitoredFolder: ((URL) -> Void)? = nil
    ) {
        self.coordinator = coordinator
        self.onAddMonitoredFolder = onAddMonitoredFolder
        self.onRemoveMonitoredFolder = onRemoveMonitoredFolder
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                monitoredRootsSection
                workspaceProfilesSection
                footerNote
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workspace Profiles")
                .font(.title2.bold())

            Text("这里可以查看 Finder 与桌面右键当前覆盖的目录，并直接增删监控范围。")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusChip(
                    title: "Desktop",
                    value: coverageSummary(for: builtInRoots[0]).title,
                    tint: coverageSummary(for: builtInRoots[0]).tint
                )
                statusChip(
                    title: "Documents",
                    value: coverageSummary(for: builtInRoots[1]).title,
                    tint: coverageSummary(for: builtInRoots[1]).tint
                )
                statusChip(
                    title: "Downloads",
                    value: coverageSummary(for: builtInRoots[2]).title,
                    tint: coverageSummary(for: builtInRoots[2]).tint
                )

                Spacer(minLength: 0)
            }
        }
    }

    private var monitoredRootsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Monitored Folders",
                subtitle: "Desktop、Documents、Downloads 默认纳入覆盖范围，你也可以继续添加更多目录。"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(builtInRoots) { root in
                    monitoredRootCard(for: root)
                }
            }
        }
    }

    private var workspaceProfilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Workspace State",
                subtitle: "显示当前已保存的工作区配置，以及哪些目录已经被工作区规则覆盖。"
            )

            Text("系统目录覆盖 \(activeMonitoredProfiles.count)/\(builtInRoots.count)，自定义工作区 \(customProfiles.count) 个。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.persistenceState.workspaceProfiles.isEmpty {
                emptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !activeMonitoredProfiles.isEmpty {
                        groupedWorkspaceSection(
                            title: "System Roots",
                            subtitle: "Desktop / Documents / Downloads 的默认覆盖状态",
                            profiles: activeMonitoredProfiles
                        )
                    }

                    if !customProfiles.isEmpty {
                        groupedWorkspaceSection(
                            title: "Custom Workspaces",
                            subtitle: "额外添加的监控目录",
                            profiles: customProfiles
                        )
                    }
                }
            }
        }
    }

    private var footerNote: some View {
        Text("Finder Sync 会读取同一份共享状态，所以这里的目录改动会成为 Finder 与桌面右键的统一覆盖范围。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var builtInRoots: [MonitoredRootDescriptor] {
        return [
            MonitoredRootDescriptor(
                name: "Desktop",
                subtitle: "Finder 桌面空白处右键",
                url: RealUserDirectories.desktop(),
                systemImageName: "desktopcomputer"
            ),
            MonitoredRootDescriptor(
                name: "Documents",
                subtitle: "文档与资料目录",
                url: RealUserDirectories.documents(),
                systemImageName: "doc.text"
            ),
            MonitoredRootDescriptor(
                name: "Downloads",
                subtitle: "下载与临时收件箱",
                url: RealUserDirectories.downloads(),
                systemImageName: "arrow.down.circle"
            )
        ]
    }

    private var sortedWorkspaceProfiles: [WorkspaceProfile] {
        coordinator.persistenceState.workspaceProfiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var activeMonitoredProfiles: [WorkspaceProfile] {
        sortedWorkspaceProfiles.filter { profile in
            builtInRoots.contains(where: { canonicalPath($0.url) == canonicalPath(profile.rootURL) })
        }
    }

    private var customProfiles: [WorkspaceProfile] {
        sortedWorkspaceProfiles.filter { profile in
            !builtInRoots.contains(where: { canonicalPath($0.url) == canonicalPath(profile.rootURL) })
        }
    }

    private func groupedWorkspaceSection(
        title: String,
        subtitle: String,
        profiles: [WorkspaceProfile]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(profiles) { profile in
                    workspaceProfileRow(for: profile)
                }
            }
        }
    }

    private func monitoredRootCard(for root: MonitoredRootDescriptor) -> some View {
        let coverage = coverageSummary(for: root)
        let matchedProfile = matchedProfile(for: root.url)
        let isActive = matchedProfile != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: root.systemImageName)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(root.name)
                        .font(.headline)
                    Text(root.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusPill(title: coverage.title, tint: coverage.tint)
            }

            Text(root.url.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let matchedProfile {
                Text("当前由工作区 `\(matchedProfile.name)` 覆盖。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("当前还没有对应的工作区覆盖。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(isActive ? "移除监控" : "添加监控") {
                    if isActive {
                        onRemoveMonitoredFolder?(root.url)
                    } else {
                        onAddMonitoredFolder?()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActive ? onRemoveMonitoredFolder == nil : onAddMonitoredFolder == nil)

                if isActive {
                    Text("桌面支持已包含在 Finder 容器右键里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func workspaceProfileRow(for profile: WorkspaceProfile) -> some View {
        let isBuiltIn = builtInRoots.contains(where: { canonicalPath($0.url) == canonicalPath(profile.rootURL) })

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isBuiltIn ? "folder.fill" : "folder.badge.gearshape")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile.name)
                        .font(.headline)

                    if isBuiltIn {
                        Text("System Root")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(profile.rootURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text(profileSummary(for: profile))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("移除") {
                onRemoveMonitoredFolder?(profile.rootURL)
            }
            .buttonStyle(.bordered)
            .disabled(onRemoveMonitoredFolder == nil)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有保存的工作区")
                .font(.headline)
            Text("先添加一个监控目录，Finder 与桌面右键就会开始覆盖它。")
                .foregroundStyle(.secondary)
            Button("添加监控目录") {
                onAddMonitoredFolder?()
            }
            .buttonStyle(.borderedProminent)
            .disabled(onAddMonitoredFolder == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func profileSummary(for profile: WorkspaceProfile) -> String {
        var parts: [String] = []

        if profile.pinnedActionIDs.isEmpty {
            parts.append("未固定动作")
        } else {
            parts.append("\(profile.pinnedActionIDs.count) 个固定动作")
        }

        if profile.visibilityRuleIDs.isEmpty {
            parts.append("未关联可见性规则")
        } else {
            parts.append("\(profile.visibilityRuleIDs.count) 条规则")
        }

        return parts.joined(separator: " · ")
    }

    private func matchedProfile(for url: URL) -> WorkspaceProfile? {
        let target = canonicalPath(url)
        return sortedWorkspaceProfiles.first { canonicalPath($0.rootURL) == target }
    }

    private func coverageSummary(for root: MonitoredRootDescriptor) -> (title: String, tint: Color) {
        if matchedProfile(for: root.url) != nil {
            return ("已覆盖", .green)
        }
        return ("未覆盖", .orange)
    }

    private func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct MonitoredRootDescriptor: Identifiable {
    let name: String
    let subtitle: String
    let url: URL
    let systemImageName: String

    var id: String { url.standardizedFileURL.path }
}
