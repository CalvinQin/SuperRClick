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
                
            AboutSettingsView()
                .tabItem {
                    Label(L("关于", "About"), systemImage: "info.circle")
                }
        }
        .padding(20)
    }
}

struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    if let nsImage = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "cursorarrow.and.square.on.square.dashed")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.accentColor)
                    }

                    Text("Super RClick")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("\(L("版本", "Version")) \(version) \(L("构建", "Build")) (\(build))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Designed & Built for macOS")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .formStyle(.grouped)
    }
}
