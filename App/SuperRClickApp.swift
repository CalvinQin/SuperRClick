import SwiftUI
import Shared

@main
struct SuperRClickApp: App {
    @State private var coordinator = AppCoordinator()
    // Trigger initialization to apply the correct activation policy based on AppStorage
    @StateObject private var appModeManager = AppModeManager.shared
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup("Super RClick", id: "main") {
            SuperRClickRootView(coordinator: coordinator)
                .background(MainWindowRegistrationView().frame(width: 0, height: 0))
                .task {
                    await coordinator.ensureExternalCommandMonitoring()
                }
                .environment(\.locale, languageManager.locale ?? Locale.current)
                .preferredColorScheme(isolatedColorScheme)
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .commands { SuperRClickCommands(coordinator: coordinator) }

        MenuBarExtra {
            MenuBarRootView(coordinator: coordinator)
                .task {
                    await coordinator.ensureExternalCommandMonitoring()
                }
                .environment(\.locale, languageManager.locale ?? Locale.current)
        } label: {
            Image(nsImage: RClickIcon.image(named: "brand", size: 18))
                .accessibilityLabel("Super RClick")
        }
    }
    
    init() {
        // Ensure initial policy applied on startup before SwiftUI gets far along.
        AppModeManager.shared.applyActivationPolicy()
    }

    /// Allows appearance verification without changing the user's system settings.
    private var isolatedColorScheme: ColorScheme? {
        #if DEBUG
        guard AppCoordinator.isIsolatedPreview else { return nil }
        switch ProcessInfo.processInfo.environment["SUPERRCLICK_TEST_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }
}

private struct SuperRClickCommands: Commands {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(L("设置…", "Settings…")) {
                coordinator.selectedSection = .settings
                MainWindowPresentation.show(using: openWindow)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@MainActor
enum MainWindowPresentation {
    private static weak var mainWindow: NSWindow?

    static func register(_ window: NSWindow) {
        mainWindow = window
    }

    static func unregister(_ window: NSWindow) {
        if mainWindow === window { mainWindow = nil }
    }

    static func show(using openWindow: OpenWindowAction) {
        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Captures only the window containing the main scene, regardless of its current title.
private struct MainWindowRegistrationView: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowRegistrationNSView {
        MainWindowRegistrationNSView()
    }

    func updateNSView(_ nsView: MainWindowRegistrationNSView, context: Context) { }
}

private final class MainWindowRegistrationNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        guard let window else { return }
        MainWindowPresentation.register(window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: window)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        MainWindowPresentation.unregister(window)
    }
}
