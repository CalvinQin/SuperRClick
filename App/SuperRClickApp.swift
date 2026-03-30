import SwiftUI

@main
struct SuperRClickApp: App {
    @State private var coordinator = AppCoordinator()
    // Trigger initialization to apply the correct activation policy based on AppStorage
    @StateObject private var appModeManager = AppModeManager.shared
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            SuperRClickRootView(coordinator: coordinator)
                .task {
                    await coordinator.ensureExternalCommandMonitoring()
                }
                .environment(\.locale, languageManager.locale ?? Locale.current)
        }
        .defaultSize(width: 800, height: 560)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarRootView(coordinator: coordinator)
                .task {
                    await coordinator.ensureExternalCommandMonitoring()
                }
                .environment(\.locale, languageManager.locale ?? Locale.current)
        } label: {
            Image(nsImage: NSApplication.shared.applicationIconImage.menuBarIcon)
        }
    }
    
    init() {
        // Ensure initial policy applied on startup before SwiftUI gets far along.
        AppModeManager.shared.applyActivationPolicy()
    }
}

extension NSImage {
    var menuBarIcon: NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
