import Shared
import SwiftUI
import AppKit
import FinderSync

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
                        
                        Text(L("如果 Finder 中没有 Super RClick 菜单，请前往“系统设置 → 通用 → 登录项与扩展”并启用它的 Finder 扩展。", "If you don’t see Super RClick in Finder’s context menu, enable its Finder extension in System Settings → General → Login Items & Extensions."))
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
                    guard !AppCoordinator.isIsolatedPreview else { return }
                    FIFinderSyncController.showExtensionManagementInterface()
                } label: {
                    Label(L("前往系统设置开启", "Open System Settings"), systemImage: "gearshape.arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(AppCoordinator.isIsolatedPreview)
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
