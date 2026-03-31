import SwiftUI
import AppKit
import Shared

public struct AIResultView: View {
    let title: String
    let content: String
    let onClose: () -> Void
    
    @State private var copied = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                Text(LocalizedStringKey(content))
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button(action: copyToClipboard) {
                    Label(copied ? L("已复制", "Copied") : L("复制", "Copy"),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command])
                .padding()
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 300, idealHeight: 400)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

public final class AIResultWindowController: NSWindowController {
    
    public convenience init(title: String, content: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.title = title
        
        self.init(window: window)
        
        let hostingView = NSHostingView(rootView: AIResultView(title: title, content: content) { [weak self] in
            self?.close()
        })
        window.contentView = hostingView
    }
    
    public func show() {
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
