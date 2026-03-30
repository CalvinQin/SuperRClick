import Observation
import Shared
import SwiftUI

struct CreateActionView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var subtitle = ""
    @State private var selectedIcon = "bolt"
    @State private var actionType: CustomActionType = .shellScript
    @State private var scriptContent = ""
    @State private var section: ActionSection = .automation
    @State private var fileExtensions = ""
    @State private var minimumSelection = 1

    private let commonIcons = [
        "bolt", "terminal", "doc.text", "photo", "folder",
        "arrow.triangle.2.circlepath", "wand.and.stars", "hammer",
        "gear", "link", "tray.full", "paperplane",
        "square.and.arrow.up", "externaldrive", "cpu", "network"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L("新建自定义动作", "New Custom Action"))
                    .font(.headline)
                Spacer()
                Button(L("取消", "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            // 表单内容
            Form {
                Section(L("基本信息", "Basic Info")) {
                    TextField(L("动作名称", "Action Name"), text: $name)
                    TextField(L("描述（可选）", "Description (optional)"), text: $subtitle)

                    LabeledContent(L("图标", "Icon")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(commonIcons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.body)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 6)
                                            )
                                            .foregroundStyle(selectedIcon == icon ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Section(L("执行方式", "Execution")) {
                    Picker(L("类型", "Type"), selection: $actionType) {
                        ForEach(CustomActionType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }

                    if actionType == .openApplication {
                        TextField(L("应用 Bundle ID（如 com.apple.TextEdit）", "App Bundle ID (e.g. com.apple.TextEdit)"), text: $scriptContent)
                    } else {
                        LabeledContent(L("脚本内容", "Script Content")) {
                            TextEditor(text: $scriptContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Section(L("触发条件", "Trigger Conditions")) {
                    Picker(L("分类", "Category"), selection: $section) {
                        Text(L("文件操作", "File")).tag(ActionSection.file)
                        Text(L("文本处理", "Text")).tag(ActionSection.text)
                        Text(L("自动化", "Automation")).tag(ActionSection.automation)
                        Text(L("系统", "System")).tag(ActionSection.system)
                    }

                    Stepper(
                        L("最少选择 \(minimumSelection) 个文件", "Minimum \(minimumSelection) file(s)"),
                        value: $minimumSelection,
                        in: 1...100
                    )

                    TextField(
                        L("限定文件扩展名（逗号分隔，留空不限）", "File extension filter (comma-separated, leave empty for all)"),
                        text: $fileExtensions
                    )
                }
            }
            .formStyle(.grouped)

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button(L("创建", "Create")) {
                    createAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }

    private func createAction() {
        let extensions = fileExtensions
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        let action = CustomAction(
            name: name.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            systemImageName: selectedIcon,
            actionType: actionType,
            scriptContent: scriptContent,
            section: section,
            fileExtensionFilter: extensions,
            minimumSelectionCount: minimumSelection
        )

        coordinator.addCustomAction(action)
        dismiss()
    }
}
