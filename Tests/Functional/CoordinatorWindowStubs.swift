// These boundaries intentionally suppress window presentation in the coordinator
// functional harness. AppCoordinator, PlatformActionExecutor, persistence, and
// the production TaskProgressInfo value type are compiled without replacements.
import AppKit
import SwiftUI

@MainActor
final class TaskProgressWindowController {
    static let shared = TaskProgressWindowController()
    private(set) var showCount = 0

    func show(info: Binding<TaskProgressInfo?>) { showCount += 1 }
    func scheduleAutoClose(delay: TimeInterval = 3) { }
    func close() { }
}

@MainActor
final class BatchRenameWindowController {
    static let shared = BatchRenameWindowController()
    func show(coordinator: AppCoordinator) { }
    func close() { }
}

struct BatchRenamePanelHost: View {
    let coordinator: AppCoordinator
    var body: some View { Color.clear }
}

@MainActor
enum MainWindowPresentation {
    static func show(using openWindow: OpenWindowAction) { }
}
