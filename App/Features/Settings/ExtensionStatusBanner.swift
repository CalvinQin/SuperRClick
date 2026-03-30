import Shared
import SwiftUI
import AppKit

struct ExtensionStatusBanner: View {
    @AppStorage("hasDismissedExtensionBanner") private var hasDismissed = false

    var body: some View {
        if !hasDismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.applepodcasts")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("需要启用 Finder 扩展", "Finder Extension Required"))
                            .font(.headline)
                        
                        Text(L("如果您没有在 Finder 中看到 Super RClick 的右键菜单，请前往“系统设置 > 隐私与安全性 > 扩展 > 附加的扩展”并勾选启用它。", "If you don’t see Super RClick in Finder’s context menu, go to System Settings > Privacy & Security > Extensions > Added Extensions and enable it."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            hasDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    // Open macOS Extensions Preferences (Ventura/Sonoma/Sequoia path)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions") {
                        // Fallback for older macOS
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(L("前往系统设置开启", "Open System Settings"), systemImage: "gearshape.arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.bottom, 8)
        }
    }
}
