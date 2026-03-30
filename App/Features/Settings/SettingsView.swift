import Observation
import SwiftUI

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
                    Label("Workspaces", systemImage: "folder")
                }
        }
        .padding(20)
    }
}
