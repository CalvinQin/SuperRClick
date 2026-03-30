import Observation
import Shared
import SwiftUI

// MARK: - Sidebar 导航枚举

enum SidebarSection: String, CaseIterable, Identifiable {
    case actionLibrary
    case pinned
    case recent
    case workspaces
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actionLibrary: L("动作库", "Actions")
        case .pinned: L("已固定", "Pinned")
        case .recent: L("最近使用", "Recent")
        case .workspaces: L("工作空间", "Workspaces")
        case .settings: L("设置", "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .actionLibrary: "square.grid.2x2"
        case .pinned: "pin"
        case .recent: "clock.arrow.circlepath"
        case .workspaces: "folder"
        case .settings: "gearshape"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .actionLibrary: .blue
        case .pinned: .blue
        case .recent: .blue
        case .workspaces: .blue
        case .settings: .secondary
        }
    }
}

// MARK: - 主视图

struct SuperRClickRootView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var selectedSection: SidebarSection?
    @State private var isPresentingCreateAction = false
    @State private var isPresentingSetup = false

    var body: some View {
        NavigationSplitView {
            sidebar
                // Shift down to avoid traffic lights since titlebar is hidden
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Spacer() // Preserves space for window controls
                    }
                }
        } detail: {
            // Apply subtle background effect to the detail side
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isPresentingCreateAction) {
            CreateActionView(coordinator: coordinator)
        }
        .sheet(isPresented: $isPresentingSetup) {
            SetupCenterView(coordinator: coordinator)
        }
        .background(BatchRenamePanelHost(coordinator: coordinator))
        .task {
            if selectedSection == nil {
                selectedSection = .actionLibrary
                if !coordinator.hasCompletedSetup {
                    isPresentingSetup = true
                }
            }
            coordinator.refreshSetupStatus()
        }
        .onChange(of: coordinator.isPresentingSetupCenter) { _, isPresenting in
            guard isPresenting else { return }
            isPresentingSetup = true
            coordinator.isPresentingSetupCenter = false
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section(L("应用", "App")) {
                ForEach([SidebarSection.actionLibrary, .pinned, .recent], id: \.self) { section in
                    sidebarRow(section)
                }
            }

            Section(L("系统", "System")) {
                ForEach([SidebarSection.workspaces, .settings], id: \.self) { section in
                    sidebarRow(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private func sidebarRow(_ section: SidebarSection) -> some View {
        Label {
            HStack {
                Text(section.title)
                Spacer()
                if section == .pinned {
                    Text("\(coordinator.pinnedActions.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(section.iconColor, in: Capsule())
                }
                if section == .recent {
                    Text("\(coordinator.recentHistory.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(section.iconColor, in: Capsule())
                }
            }
        } icon: {
            Image(systemName: section.systemImage)
                .foregroundStyle(section.iconColor)
        }
        .tag(section)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()
            Button {
                isPresentingCreateAction = true
            } label: {
                Label(L("新建动作", "New Action"), systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            // Hover effect on new action button could be implemented with custom ButtonStyle,
            // but for native mac feel, plain + hover state or just simple text label is enough.

            // 状态指示
            if coordinator.isReady {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(L("就绪", "Ready"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .actionLibrary:
            ActionLibraryView(coordinator: coordinator)
        case .pinned:
            PinnedActionsView(coordinator: coordinator)
        case .recent:
            RecentActivityView(coordinator: coordinator)
        case .workspaces:
            WorkspaceSettingsView(coordinator: coordinator)
        case .settings:
            GeneralSettingsView(coordinator: coordinator)
        case nil:
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            
            Text(L("选择一个栏目", "Select a section"))
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helper component for Mac blur

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
