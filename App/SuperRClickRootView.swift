import Observation
import Shared
import SwiftUI

// MARK: - Sidebar 导航枚举

enum SidebarSection: String, CaseIterable, Identifiable {
    case actionLibrary
    case pinned
    case recent
    case tools
    case workspaces
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actionLibrary: L("动作库", "Actions")
        case .pinned: L("已固定", "Pinned")
        case .recent: L("最近使用", "Recent")
        case .tools: L("工具箱", "Toolbox")
        case .workspaces: L("工作空间", "Workspaces")
        case .settings: L("设置", "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .actionLibrary: "square.grid.2x2.fill"
        case .pinned: "pin.fill"
        case .recent: "clock.arrow.circlepath"
        case .tools: "wrench.and.screwdriver.fill"
        case .workspaces: "folder.fill"
        case .settings: "gearshape.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .actionLibrary: .blue
        case .pinned: .orange
        case .recent: .secondary
        case .tools: .purple
        case .workspaces: .teal
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
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Spacer()
                    }
                }
        } detail: {
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

            Section(L("工具", "Tools")) {
                sidebarRow(.tools)
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
                // Only show badge for pinned when count > 0
                if section == .pinned, coordinator.pinnedActions.count > 0 {
                    Text("\(coordinator.pinnedActions.count)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        } icon: {
            Image(systemName: section.systemImage)
                .foregroundStyle(section.iconColor)
                .symbolRenderingMode(.hierarchical)
        }
        .tag(section)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 12)
            
            Button {
                isPresentingCreateAction = true
            } label: {
                Label(L("新建动作", "New Action"), systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if coordinator.isReady {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: .green.opacity(0.5), radius: 3)
                    Text(L("就绪", "Ready"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        case .tools:
            ToolsView(coordinator: coordinator)
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
