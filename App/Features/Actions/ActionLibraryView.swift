import Observation
import Shared
import SwiftUI

struct ActionLibraryView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var searchText = ""
    @State private var scope = LibraryScope.all
    @State private var category: ActionSection?
    @State private var actionToDelete: CustomAction?

    private enum LibraryScope: String, CaseIterable, Identifiable {
        case all, builtIn, custom
        var id: Self { self }
        var title: String {
            switch self {
            case .all: L("全部", "All actions")
            case .builtIn: L("内置", "Built-in")
            case .custom: L("自定义", "Custom")
              }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()
                if !coordinator.isReady {
                    ProgressView(L("正在载入动作…", "Loading actions…"))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if resultCount == 0 {
                    emptyState.frame(minHeight: 240)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(builtInSections) { section in
                            actionGroup(title: section.section.displayName, count: section.actions.count) {
                                ForEach(section.actions) { action in
                                    builtInRow(action)
                                    if action.id != section.actions.last?.id { rowDivider }
                                }
                            }
                        }
                        if !customActions.isEmpty {
                            actionGroup(title: L("自定义动作", "Custom actions"), count: customActions.count) {
                                ForEach(customActions) { action in
                                    customRow(action)
                                    if action.id != customActions.last?.id { rowDivider }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle(L("动作库", "Actions"))
        .searchable(text: $searchText, prompt: L("搜索名称或描述", "Search names and descriptions"))
        .toolbar {
            ToolbarItem {
                Button { coordinator.refresh() } label: {
                    RClickLabel(L("刷新", "Refresh"), icon: "arrow.clockwise")
                }
                .help(L("刷新动作库", "Refresh actions"))
            }
            ToolbarItem {
                Button { coordinator.presentActionEditor() } label: {
                    RClickLabel(L("新建动作", "New Action"), icon: "plus")
                }
                .disabled(!coordinator.isReady)
                .keyboardShortcut("n")
                .accessibilityIdentifier("library.newAction")
              }
        }
        .alert(L("删除此动作？", "Delete this action?"), isPresented: Binding(
            get: { actionToDelete != nil }, set: { if !$0 { actionToDelete = nil } }
        ), presenting: actionToDelete) { action in
            Button(L("取消", "Cancel"), role: .cancel) { actionToDelete = nil }
            Button(L("删除", "Delete"), role: .destructive) {
                coordinator.deleteCustomAction(action)
                actionToDelete = nil
              }
        } message: { action in
            Text(L("“\(action.name)”将从 Finder 菜单中移除。此操作无法撤销。", "“\(action.name)” will be removed from your Finder menu. This cannot be undone."))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("让右键菜单更顺手", "Make Finder work your way"))
                        .font(.title2.weight(.semibold))
                    Text(L("选择显示在 Finder 中的动作，固定常用项，或创建自己的命令。", "Choose what appears in Finder, pin your favorites, or add your own commands."))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 20)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(coordinator.allDefinitions.count + coordinator.persistenceState.customActions.count)")
                        .font(.title2.weight(.semibold)).monospacedDigit()
                    Text(L("个动作", "actions")).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 16) {
                Picker(L("动作来源", "Action source"), selection: $scope) {
                    ForEach(LibraryScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 310)
                .accessibilityLabel(L("动作来源", "Action source"))
                .accessibilityIdentifier("library.scope")
                Spacer(minLength: 0)
                Picker(L("分类", "Category"), selection: $category) {
                    Text(L("所有分类", "All categories")).tag(Optional<ActionSection>.none)
                    ForEach(ActionSection.allCases, id: \.self) { section in
                        Text(section.displayName).tag(Optional(section))
                    }
                }
                .labelsHidden().frame(maxWidth: 165)
                .accessibilityLabel(L("分类", "Category"))
                .accessibilityIdentifier("library.category")
            }
            HStack {
                Text(L("\(resultCount) 个结果", "\(resultCount) results"))
                Spacer()
                Text(L("固定", "Pin")).frame(width: 38)
                Text(L("在 Finder 中显示", "Show in Finder")).frame(width: 108, alignment: .trailing)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).padding(.bottom, -8)
    }

    private func actionGroup<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.headline)
                Text("\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            VStack(spacing: 0, content: content)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5) }
        }
    }

    private var rowDivider: some View { Divider().padding(.leading, 62) }

    private func builtInRow(_ action: ActionDefinition) -> some View {
        HStack(spacing: 12) {
            ActionSymbol(name: action.systemImageName ?? "bolt", tint: action.section.tint)
            rowTitle(action.title, subtitle: action.subtitle)
            Spacer(minLength: 8)
            Button { coordinator.togglePinned(action) } label: {
                Image(rclick: coordinator.isPinned(action) ? "pin.fill" : "pin")
                    .foregroundStyle(coordinator.isPinned(action) ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(coordinator.isPinned(action) ? L("取消固定", "Unpin action") : L("固定到面板", "Pin action"))
            .accessibilityLabel((coordinator.isPinned(action) ? L("取消固定 ", "Unpin ") : L("固定 ", "Pin ")) + action.title)
            .accessibilityIdentifier("pin.\(action.id.rawValue)")
            Toggle(L("在 Finder 中显示 ", "Show in Finder: ") + action.title, isOn: Binding(
                get: { !coordinator.isActionHidden(action) },
                set: { coordinator.setActionHidden(action, isHidden: !$0) }
            ))
            .labelsHidden().toggleStyle(.switch).controlSize(.small)
            .frame(width: 108, alignment: .trailing)
            .accessibilityIdentifier("visibility.\(action.id.rawValue)")
        }
        .padding(14)
        .contextMenu {
            Button(coordinator.isPinned(action) ? L("取消固定", "Unpin") : L("固定到面板", "Pin to Panel")) {
                coordinator.togglePinned(action)
              }
        }
    }

    private func customRow(_ action: CustomAction) -> some View {
        HStack(spacing: 12) {
            ActionSymbol(name: action.systemImageName, tint: .orange)
            Button { coordinator.presentActionEditor(action) } label: {
                rowTitle(action.name, subtitle: action.subtitle.isEmpty ? action.actionType.displayName : action.subtitle)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("编辑 ", "Edit ") + action.name)
            .accessibilityIdentifier("edit.\(action.id.uuidString)")
            Spacer(minLength: 8)
            Menu {
                Button(L("编辑动作…", "Edit Action…")) { coordinator.presentActionEditor(action) }
                Divider()
                Button(L("删除动作…", "Delete Action…"), role: .destructive) { actionToDelete = action }
            } label: {
                Image(rclick: "ellipsis").frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(L("动作选项：", "Action options: ") + action.name)
            .accessibilityIdentifier("options.\(action.id.uuidString)")
            Toggle(L("在 Finder 中显示 ", "Show in Finder: ") + action.name, isOn: Binding(
                get: { action.isEnabled },
                set: { coordinator.setCustomActionEnabled(action, isEnabled: $0) }
            ))
            .labelsHidden().toggleStyle(.switch).controlSize(.small)
            .frame(width: 108, alignment: .trailing)
            .accessibilityIdentifier("enabled.\(action.id.uuidString)")
        }
        .padding(14)
    }

    private func rowTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
              }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            RClickLabel(scope == .custom && query.isEmpty && category == nil
                  ? L("创建你的第一个动作", "Create your first action") : L("没有匹配的动作", "No matching actions"),
                  icon: scope == .custom && query.isEmpty ? "terminal" : "magnifyingglass")
        } description: {
            Text(scope == .custom && query.isEmpty && category == nil
                 ? L("将 Shell 脚本、AppleScript 或常用应用加入 Finder 右键菜单。", "Add a shell script, AppleScript, or an app to your Finder menu.")
                 : L("尝试其他关键词，或清除搜索和筛选条件。", "Try another search, or clear your search and filters."))
        } actions: {
            if query.isEmpty && category == nil && scope == .custom {
                Button(L("新建动作", "New Action")) { coordinator.presentActionEditor() }.buttonStyle(.borderedProminent)
            } else {
                Button(L("清除搜索与筛选", "Clear Search & Filters")) {
                    searchText = ""
                    scope = .all
                    category = nil
                }
                .accessibilityIdentifier("library.clearFilters")
              }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("library.emptyState")
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func matches(_ title: String, _ subtitle: String?) -> Bool {
        query.isEmpty || title.localizedStandardContains(query) || (subtitle?.localizedStandardContains(query) ?? false)
    }
    private var builtInSections: [AppCoordinator.ActionSectionSnapshot] {
        guard scope != .custom else { return [] }
        return coordinator.actionSections.compactMap { section in
            guard category == nil || category == section.section else { return nil }
            let actions = section.actions.filter { matches($0.title, $0.subtitle) }
            return actions.isEmpty ? nil : .init(section: section.section, actions: actions)
        }
    }
    private var customActions: [CustomAction] {
        guard scope != .builtIn else { return [] }
        return coordinator.persistenceState.customActions.filter {
            (category == nil || category == $0.section) && matches($0.name, $0.subtitle)
        }
    }
    private var resultCount: Int { builtInSections.reduce(0) { $0 + $1.actions.count } + customActions.count }
}
