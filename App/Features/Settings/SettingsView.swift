import Observation
import SwiftUI
import Shared

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        TabView {
            ActionVisibilityView(coordinator: coordinator)
                .tabItem {
                    Label("Actions", systemImage: "slider.horizontal.3")
                }

            WorkspaceProfileView(
                coordinator: coordinator,
                onAddMonitoredFolder: { coordinator.promptForMonitoredFolder() },
                onRemoveMonitoredFolder: { coordinator.removeMonitoredFolder($0) }
            )
                .tabItem {
                    Label(L("工作区", "Workspaces"), systemImage: "folder")
                }
                
            AISettingsView(config: $coordinator.persistenceState.aiConfig) {
                coordinator.saveAIConfig()
            }
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .padding(20)
    }
}
