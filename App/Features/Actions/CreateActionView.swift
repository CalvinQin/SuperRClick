import Observation
import Shared
import SwiftUI

struct CreateActionView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomAction
    @State private var fileExtensions: String
    @State private var contentsByType: [CustomActionType: String]
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var confirmDiscard = false
    @FocusState private var nameFocused: Bool
    private let original: CustomAction
    private let isEditing: Bool

    init(coordinator: AppCoordinator, action: CustomAction) {
        self.coordinator = coordinator
        self.original = action
        self.isEditing = coordinator.persistenceState.customActions.contains { $0.id == action.id }
        _draft = State(initialValue: action)
        _fileExtensions = State(initialValue: action.fileExtensionFilter.joined(separator: ", "))
        _contentsByType = State(initialValue: [action.actionType: action.scriptContent])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ActionSymbol(name: draft.systemImageName, tint: .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isEditing ? L("编辑动作", "Edit Action") : L("新建动作", "New Action"))
                        .font(.title3.weight(.semibold))
                    Text(L("保存后即可在 Finder 右键菜单中使用。", "Available in your Finder menu after saving."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()
            Form {
                Section(L("基本信息", "Details")) {
                    TextField(L("名称", "Name"), text: $draft.name)
                        .focused($nameFocused).accessibilityIdentifier("action.name")
                    TextField(L("描述", "Description"), text: $draft.subtitle, prompt: Text(L("可选", "Optional")))
                        .accessibilityIdentifier("action.description")
                    Picker(L("图标", "Icon"), selection: $draft.systemImageName) {
                        ForEach(icons, id: \.0) { icon in Label(icon.1, systemImage: icon.0).tag(icon.0) }
                    }
                }
                Section {
                    Picker(L("类型", "Type"), selection: $draft.actionType) {
                        ForEach(CustomActionType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .accessibilityIdentifier("action.type")
                    if draft.actionType == .openApplication {
                        TextField(L("应用名称或 Bundle ID", "App name or bundle ID"), text: $draft.scriptContent,
                                  prompt: Text("com.apple.TextEdit"))
                            .accessibilityIdentifier("action.application")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("脚本", "Script")).font(.callout.weight(.medium))
                            TextEditor(text: $draft.scriptContent)
                                .font(.system(.body, design: .monospaced)).frame(minHeight: 110)
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 1) }
                                .accessibilityLabel(L("脚本内容", "Script content"))
                                .accessibilityIdentifier("action.script")
                        }
                    }
                    Text(executionHelp).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                } header: { Text(L("执行方式", "Execution")) }
                Section(L("显示条件", "Availability")) {
                    Picker(L("分类", "Category"), selection: $draft.section) {
                        ForEach([ActionSection.file, .text, .automation, .system], id: \.self) { section in
                            Text(section.displayName).tag(section)
                        }
                    }
                    Stepper(L("至少选择 \(draft.minimumSelectionCount) 个项目", "At least \(draft.minimumSelectionCount) selected item(s)"),
                            value: $draft.minimumSelectionCount, in: 1...100)
                    TextField(L("文件扩展名", "File extensions"), text: $fileExtensions, prompt: Text("txt, pdf, png"))
                        .accessibilityIdentifier("action.extensions")
                    Text(L("用逗号分隔，留空适用于所有文件；扩展名不区分大小写。", "Separate with commas, or leave empty for all files. Extensions are case-insensitive."))
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(L("在 Finder 中显示", "Show in Finder"), isOn: $draft.isEnabled)
                }
            }
            .formStyle(.grouped)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                        .accessibilityIdentifier("action.saveError")
                }
                HStack {
                    if !hasRequiredFields {
                        Text(L("请填写名称和执行内容。", "Enter a name and an action to run."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("取消", "Cancel"), action: cancel)
                        .keyboardShortcut(.cancelAction).disabled(isSaving).accessibilityIdentifier("action.cancel")
                    Button(isEditing ? L("保存更改", "Save Changes") : L("创建动作", "Create Action"), action: save)
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(!hasRequiredFields || isSaving).accessibilityIdentifier("action.save")
                }
            }
            .padding(20)
        }
        .frame(width: 600, height: 660)
        .interactiveDismissDisabled(hasChanges || isSaving)
        .onAppear { nameFocused = true }
        .onChange(of: draft.actionType) { oldValue, newValue in
            contentsByType[oldValue] = draft.scriptContent
            draft.scriptContent = contentsByType[newValue] ?? ""
            saveError = nil
        }
        .confirmationDialog(L("放弃未保存的更改？", "Discard unsaved changes?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L("放弃更改", "Discard Changes"), role: .destructive) { dismiss() }
            Button(L("继续编辑", "Keep Editing"), role: .cancel) { }
        }
    }

    private var hasRequiredFields: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.scriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasChanges: Bool {
        draft != original || fileExtensions != original.fileExtensionFilter.joined(separator: ", ")
    }
    private var executionHelp: String {
        switch draft.actionType {
        case .shellScript:
            L("使用 /bin/sh 执行。可读取 $FIRST_FILE、$SELECTED_FILES（每行一个路径）及 $TARGET_DIR。路径变量请加双引号。",
              "Runs with /bin/sh. Use $FIRST_FILE, $SELECTED_FILES (one path per line), and $TARGET_DIR. Double-quote path variables.")
        case .appleScript:
            L("使用 osascript 执行。通过 system attribute 读取 FIRST_FILE、SELECTED_FILES 或 TARGET_DIR。",
              "Runs with osascript. Read FIRST_FILE, SELECTED_FILES, or TARGET_DIR using system attribute.")
        case .openApplication:
            L("用指定的应用打开 Finder 中选中的文件。", "Opens the files selected in Finder with this application.")
        }
    }
    private var icons: [(String, String)] {
        var values = [("bolt", L("闪电", "Bolt")), ("terminal", L("终端", "Terminal")),
                      ("doc.text", L("文档", "Document")), ("photo", L("图片", "Image")),
                      ("folder", L("文件夹", "Folder")), ("hammer", L("工具", "Tool")),
                      ("gear", L("设置", "Gear")), ("link", L("链接", "Link"))]
        if !values.contains(where: { $0.0 == draft.systemImageName }) {
            values.append((draft.systemImageName, L("当前图标", "Current icon")))
        }
        return values
    }
    private func cancel() {
        if hasChanges { confirmDiscard = true } else { dismiss() }
    }
    private func save() {
        guard !isSaving, hasRequiredFields else { return }
        isSaving = true
        defer { isSaving = false }
        var action = draft
        action.fileExtensionFilter = CustomAction.parseFileExtensions(fileExtensions)
        do {
            try coordinator.saveCustomAction(action)
            dismiss()
        } catch {
            saveError = L("未能保存。", "Could not save. ") + error.localizedDescription
        }
    }
}
