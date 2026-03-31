import AppKit
import Observation
import Shared
import SwiftUI

struct BatchRenamePanelHost: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        Color.clear
            .onChange(of: coordinator.isPresentingBatchRename) { _, isPresenting in
                if isPresenting {
                    BatchRenameWindowController.shared.show(coordinator: coordinator)
                } else {
                    BatchRenameWindowController.shared.close()
                }
            }
    }
}

// MARK: - Standalone NSPanel for batch rename

@MainActor
final class BatchRenameWindowController {
    static let shared = BatchRenameWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?

    private init() {}

    func show(coordinator: AppCoordinator) {
        // If window already exists, just bring it forward
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSLog("[SuperRClick] BatchRenameWindowController.show: creating new window")

        let content = BatchRenamePanelView(coordinator: coordinator)
            .environment(\.locale, LanguageManager.shared.locale ?? Locale.current)

        let hostingView = NSHostingView(rootView: AnyView(content))

        // Match the SwiftUI view's minimum dimensions to avoid layout conflicts
        let windowRect = NSRect(x: 0, y: 0, width: 780, height: 700)
        hostingView.frame = windowRect

        let win = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = L("批量重命名", "Batch Rename")
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 780, height: 700)

        // When user closes the window via the red button, dismiss the coordinator state
        win.delegate = BatchRenamePanelDelegate.shared
        BatchRenamePanelDelegate.shared.coordinator = coordinator

        self.window = win
        self.hostingView = hostingView

        NSLog("[SuperRClick] BatchRenameWindowController.show: about to makeKeyAndOrderFront")
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        NSLog("[SuperRClick] BatchRenameWindowController.show: window is now visible")
    }

    func close() {
        // Guard against re-entry: close() → windowWillClose → dismissBatchRename → closeBatchRenamePanel → close()
        guard let win = window else { return }
        // Remove delegate FIRST to prevent windowWillClose from calling dismissBatchRename again
        win.delegate = nil
        window = nil
        hostingView = nil
        win.close()
    }
}

// MARK: - Panel delegate to handle close button

@MainActor
final class BatchRenamePanelDelegate: NSObject, NSWindowDelegate {
    static let shared = BatchRenamePanelDelegate()
    weak var coordinator: AppCoordinator?

    func windowWillClose(_ notification: Notification) {
        coordinator?.dismissBatchRename()
    }
}

struct BatchRenamePanelView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var draft = BatchRenameDraft()
    @FocusState private var isTokenFocused: Bool
    @State private var didInitialSync = false

    private let planner = BatchRenamePlanner()

    var body: some View {
        let plan = planner.makePlan(for: draft.request)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard(plan: plan)
                controlsCard
                previewCard(plan: plan)
                conflictCard(plan: plan)
                actionBar(plan: plan)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 680)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear(perform: syncDraftFromCoordinator)
        .onChange(of: draft) { _, newValue in
            guard didInitialSync else { return }
            coordinator.updateBatchRenameDraft(newValue)
        }
    }

    private func syncDraftFromCoordinator() {
        if draft.items.isEmpty {
            draft = coordinator.batchRenameDraft
        }
        didInitialSync = true
    }

    private func headerCard(plan: BatchRenamePlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("批量重命名", "Batch Rename"))
                        .font(.largeTitle.bold())

                    Text(L("原生预览、冲突提示与执行。先调整规则，再一次性应用到选中的文件。", "Native preview, conflict detection, and execution. Fine-tune rules before applying."))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(plan.summary)
                        .font(.headline)
                    Text(coordinator.sampleContext.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                metricChip(title: L("项目", "Items"), value: "\(draft.items.count)")
                metricChip(title: L("预览", "Preview"), value: "\(plan.previews.count)")
                metricChip(title: L("冲突", "Conflicts"), value: "\(plan.conflicts.count)")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary.opacity(0.72))
        )
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(L("重命名规则", "Rename Rules"), subtitle: L("这些设置会实时生成预览。", "These settings generate real-time previews."))

            VStack(alignment: .leading, spacing: 14) {
                Picker(L("模式", "Mode"), selection: draftModeBinding) {
                    Text(L("前缀", "Prefix")).tag(BatchRenameMode.prefix)
                    Text(L("后缀", "Suffix")).tag(BatchRenameMode.suffix)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("标记 (Token)", "Token"))
                        .font(.subheadline.weight(.semibold))
                    TextField(L("输入标记，比如 IMG 或 ARCHIVE", "Type a label, such as IMG or ARCHIVE"), text: tokenBinding)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTokenFocused)
                }

                Toggle(L("启用数字序列", "Enable numbering"), isOn: numberingEnabledBinding)

                HStack(spacing: 12) {
                    Stepper(L("起始", "Start") + " \(draft.numbering.start)", value: numberingStartBinding, in: 0...9999)
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)

                    Stepper(L("补齐", "Padding") + " \(draft.numbering.padding)", value: numberingPaddingBinding, in: 0...6)
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
                }

                Text(L("数字序列有助于保持重命名项目的稳定和可排序性。", "Numbering helps keep renamed items stable and sortable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func previewCard(plan: BatchRenamePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(L("预览", "Preview"), subtitle: L("先看清楚结果，再点应用。", "Check the result before applying."))

            if plan.previews.isEmpty {
                emptyStateCard(
                    title: L("未选择任何项目", "No items selected"),
                    detail: L("请选择至少一个文件或文件夹，重命名预览才会出现。", "Select at least one file or folder to see the preview.")
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(plan.previews) { preview in
                        BatchRenamePreviewRow(preview: preview)
                    }
                }
            }
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func conflictCard(plan: BatchRenamePlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(L("冲突", "Conflicts"), subtitle: L("有冲突时会阻止应用。", "Application is blocked when conflicts exist."))

            if plan.conflicts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(L("未检测到冲突", "No conflicts detected"))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(plan.conflicts) { conflict in
                        BatchRenameConflictRow(conflict: conflict)
                    }
                }
            }
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func actionBar(plan: BatchRenamePlan) -> some View {
        HStack {
            Button(L("取消", "Cancel")) {
                coordinator.dismissBatchRename()
            }

            Spacer()

            Button(L("应用更改", "Apply Changes")) {
                coordinator.applyBatchRename()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!plan.canApply)
        }
        .padding(.horizontal, 4)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func emptyStateCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var draftModeBinding: Binding<BatchRenameMode> {
        Binding(
            get: { draft.mode },
            set: { newValue in
                draft.mode = newValue
            }
        )
    }

    private var tokenBinding: Binding<String> {
        Binding(
            get: { draft.token },
            set: { newValue in
                draft.token = newValue
            }
        )
    }

    private var numberingEnabledBinding: Binding<Bool> {
        Binding(
            get: { draft.numbering.isEnabled },
            set: { newValue in
                draft.numbering.isEnabled = newValue
            }
        )
    }

    private var numberingStartBinding: Binding<Int> {
        Binding(
            get: { draft.numbering.start },
            set: { newValue in
                draft.numbering.start = newValue
            }
        )
    }

    private var numberingPaddingBinding: Binding<Int> {
        Binding(
            get: { draft.numbering.padding },
            set: { newValue in
                draft.numbering.padding = newValue
            }
        )
    }
}

private struct BatchRenamePreviewRow: View {
    let preview: BatchRenamePreviewItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(preview.sourceName)
                    .font(.headline)
                Text(preview.proposedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(statusColor)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusLabel: String {
        switch preview.status {
        case .ready:
            return L("准备就绪", "Ready")
        case .unchanged:
            return L("无更改", "Unchanged")
        case .duplicateProposedName:
            return L("重名冲突", "Duplicate")
        case .existingFileOnDisk:
            return L("目标已存在", "Exists")
        case .invalidName:
            return L("无效名称", "Invalid")
        }
    }

    private var statusColor: Color {
        switch preview.status {
        case .ready:
            return .green
        case .unchanged:
            return .secondary
        case .duplicateProposedName, .existingFileOnDisk, .invalidName:
            return .orange
        }
    }

    private var iconName: String {
        switch preview.status {
        case .ready:
            return "checkmark.circle.fill"
        case .unchanged:
            return "minus.circle.fill"
        case .duplicateProposedName, .existingFileOnDisk, .invalidName:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct BatchRenameConflictRow: View {
    let conflict: BatchRenameConflict

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(conflict.kind.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
            }

            Text(conflict.message)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
