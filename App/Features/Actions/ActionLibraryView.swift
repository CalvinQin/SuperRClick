import Observation
import Shared
import SwiftUI

struct ActionLibraryView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                actionSections
            }
            .padding(28)
            .padding(.top, 8)
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
        HStack(spacing: 14) {
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
                tint: .orange
            )
            statChip(
                title: L("已固定", "Pinned"),
                value: "\(coordinator.pinnedActions.count)",
                icon: "pin.fill",
                tint: .purple
            )
        }
    }

    // MARK: - Action Sections

    private var actionSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(filteredBuiltInSections) { section in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(sectionDisplayName(section.section))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("\(section.actions.count)")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                        ForEach(section.actions) { action in
                            actionCard(action)
                        }
                    }
                }
            }

            if !filteredCustomActions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(L("自定义动作", "Custom Actions"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("\(filteredCustomActions.count)")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
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
        let tint = sectionTint(action.section)

        return ActionCardView(
            title: action.title,
            subtitle: action.subtitle,
            systemImage: action.systemImageName ?? "bolt.fill",
            tint: tint,
            isPinned: isPinned
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
        ActionCardView(
            title: custom.name,
            subtitle: custom.subtitle.isEmpty ? nil : custom.subtitle,
            systemImage: custom.systemImageName,
            tint: .orange,
            isPinned: false,
            badge: custom.actionType.displayName
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
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title2.weight(.heavy))
                    .monospacedDigit()
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1.5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func sectionDisplayName(_ section: ActionSection) -> String {
        switch section {
        case .file: L("文件操作", "File Actions")
        case .newFile: L("新建快捷文件", "New File Templates")
        case .text: L("文本处理", "Text Processing")
        case .automation: L("自动化与工作流", "Automation & Workflows")
        case .system: L("系统控制", "System")
        case .ai: L("AI 智能辅助", "AI Actions")
        }
    }

    private func sectionTint(_ section: ActionSection) -> Color {
        switch section {
        case .file: .blue
        case .newFile: .teal
        case .text: .indigo
        case .automation: .green
        case .system: .secondary
        case .ai: .purple
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

// MARK: - Extracted Action Card Component

private struct ActionCardView: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color
    let isPinned: Bool
    var badge: String? = nil

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                Spacer()
                
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(-15))
                }
                
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.1), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(
                    color: isHovered ? tint.opacity(0.08) : .black.opacity(0.03),
                    radius: isHovered ? 8 : 3,
                    y: isHovered ? 3 : 1.5
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isHovered ? tint.opacity(0.25) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isHovered ? 1.2 : 0.5
                )
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
