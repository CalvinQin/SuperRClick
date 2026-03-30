import AppKit
import SwiftUI

@MainActor
final class AppModeManager: ObservableObject {
    static let shared = AppModeManager()

    @AppStorage("showInDock") var showInDock: Bool = true {
        didSet {
            applyActivationPolicy()
        }
    }

    private init() {
        // Initialization
    }

    func applyActivationPolicy() {
        if showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
            // If transitioning to regular, we might want to ensure it's unhidden/activated
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
            // Note: switching back to accessory mid-run requires closing remaining normal windows manually
            // or letting the user intuitively understand it sits in the menubar now.
        }
    }
}
