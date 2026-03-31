import AppKit
import Shared
import SwiftUI

// MARK: - Progress Info Model

struct TaskProgressInfo: Identifiable, Equatable {
    let id = UUID()
    let title: String
    var detail: String
    var current: Int
    var total: Int
    var isComplete: Bool = false
    var resultMessage: String?
    var isSuccess: Bool = true

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    static func == (lhs: TaskProgressInfo, rhs: TaskProgressInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.current == rhs.current &&
        lhs.total == rhs.total &&
        lhs.isComplete == rhs.isComplete &&
        lhs.detail == rhs.detail
    }
}

// MARK: - Progress Window Controller

@MainActor
final class TaskProgressWindowController {
    static let shared = TaskProgressWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var autoCloseTask: Task<Void, Never>?

    private init() {}

    func show(info: Binding<TaskProgressInfo?>) {
        close()

        let content = TaskProgressView(info: info, onClose: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: AnyView(content))
        let windowRect = NSRect(x: 0, y: 0, width: 340, height: 130)
        hostingView.frame = windowRect

        let win = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.center()
        win.isReleasedWhenClosed = false
        win.contentView = hostingView
        win.backgroundColor = .clear
        win.hasShadow = true

        self.window = win
        self.hostingView = hostingView

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func scheduleAutoClose(delay: TimeInterval = 3.0) {
        autoCloseTask?.cancel()
        autoCloseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            close()
        }
    }

    func close() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        guard let win = window else { return }
        window = nil
        hostingView = nil
        win.close()
    }
}

// MARK: - Progress SwiftUI View

private struct TaskProgressView: View {
    @Binding var info: TaskProgressInfo?
    let onClose: () -> Void

    var body: some View {
        if let info {
            VStack(spacing: 0) {
                if info.isComplete {
                    completedView(info: info)
                } else {
                    progressView(info: info)
                }
            }
            .frame(width: 340, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func progressView(info: TaskProgressInfo) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)

                Text(info.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(info.current)/\(info.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: info.fraction)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Image(systemName: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(info.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func completedView(info: TaskProgressInfo) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: info.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(info.isSuccess ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.headline)

                    if let msg = info.resultMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            ProgressView(value: 1.0)
                .progressViewStyle(.linear)
                .tint(info.isSuccess ? .green : .orange)

            HStack {
                Spacer()

                Button(action: onClose) {
                    Text(L("关闭", "Close"))
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
