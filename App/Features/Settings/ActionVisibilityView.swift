import Observation
import Shared
import SwiftUI

struct ActionVisibilityView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Action Visibility")
                .font(.title2.bold())

            Text("在这里配置哪些动作应该出现在默认菜单中，以及哪些动作需要固定到控制台。")
                .foregroundStyle(.secondary)

            List {
                ForEach(coordinator.allDefinitions) { action in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(action.title, systemImage: action.systemImageName ?? "bolt")
                            if let subtitle = action.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Toggle("Pinned", isOn: Binding(
                            get: { coordinator.isPinned(action) },
                            set: { _ in coordinator.togglePinned(action) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        Toggle("Hidden", isOn: Binding(
                            get: { coordinator.isActionHidden(action) },
                            set: { coordinator.setActionHidden(action, isHidden: $0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
}

