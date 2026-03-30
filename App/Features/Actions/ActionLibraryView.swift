import Observation
import Shared
import SwiftUI

struct ActionLibraryView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                actionSections
            }
            .padding(24)
            .padding(.top, 10)
        }
        .searchable(text: $searchText, prompt: L("查找动作...", "Search actions..."))
        .navigationTitle(L("动作库", "Actions"))
        .toolbar {
            ToolbarItem {
                Button {
                    coordinator.refresh()
                } label: {
                    Label(L("刷新", "Refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            statChip(
                title: L("内置", "Built-in"),
                value: "\(coordinator.allDefinitions.count)",
                icon: "bolt.fill",
                tint: .blue
            )
            statChip(
                title: L("自定义", "Custom"),
                value: "\(coordinator.persistenceState.customActions.count)",
                icon: "hammer.fill",
                tint: .secondary
            )
            statChip(
                title: L("已固定", "Pinned"),
                value: "\(coordinator.pinnedActions.count)",
                icon: "pin.fill",
                tint: .secondary
            )
        }
    }

    // MARK: - Action Sections

    private var actionSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 内置动作 - 按 Section 分组
            ForEach(filteredBuiltInSections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionDisplayName(section.section))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        ForEach(section.actions) { action in
                            actionCard(action)
                        }
                    }
                }
            }

            // 自定义动作
            if !filteredCustomActions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("自定义动作", "Custom Actions"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        ForEach(filteredCustomActions) { custom in
                            customActionCard(custom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cards

    private func actionCard(_ action: ActionDefinition) -> some View {
        let isPinned = coordinator.isPinned(action)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.systemImageName ?? "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                Spacer()
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .contextMenu {
            Button(isPinned ? L("取消固定", "Unpin") : L("固定到面板", "Pin to Panel")) {
                coordinator.togglePinned(action)
            }
            Button(L("执行此动作", "Run Action")) {
                coordinator.run(action)
            }
        }
    }

    private func customActionCard(_ custom: CustomAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: custom.systemImageName)
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                Spacer()
                Text(custom.actionType.displayName)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(custom.name)
                    .font(.headline)
                    .lineLimit(1)

                if !custom.subtitle.isEmpty {
                    Text(custom.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button(L("删除动作", "Delete Action"), role: .destructive) {
                coordinator.deleteCustomAction(custom)
            }
        }
    }

    // MARK: - Helpers

    private func statChip(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.heavy))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionDisplayName(_ section: ActionSection) -> String {
        switch section {
        case .file: L("文件操作", "File Actions")
        case .newFile: L("新建快捷文件", "New File Templates")
        case .text: L("文本处理", "Text Processing")
        case .automation: L("自动化与工作流", "Automation & Workflows")
        case .system: L("系统控制", "System")
        }
    }

    private var filteredBuiltInSections: [AppCoordinator.ActionSectionSnapshot] {
        if searchText.isEmpty {
            return coordinator.actionSections
        }
        return coordinator.actionSections.compactMap { section in
            let filtered = section.actions.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return filtered.isEmpty ? nil : AppCoordinator.ActionSectionSnapshot(section: section.section, actions: filtered)
        }
    }

    private var filteredCustomActions: [CustomAction] {
        let customs = coordinator.persistenceState.customActions
        if searchText.isEmpty { return customs }
        return customs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}
