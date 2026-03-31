import Shared
import SwiftUI

struct ToolsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L("工具箱", "Toolbox"))
                    .font(.largeTitle.weight(.bold))
                    .padding(.bottom, 4)

                Text(L("常用文件操作工具，也可通过 Finder 右键菜单使用。",
                       "Frequently used file tools. Also available via Finder right-click menu."))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ToolCard(
                        title: L("批量重命名", "Batch Rename"),
                        subtitle: L("支持前缀/后缀/替换三种模式，智能编号",
                                    "Prefix, suffix, replace modes with smart numbering"),
                        icon: "pencil.and.list.clipboard",
                        color: .teal
                    ) {
                        coordinator.openBatchRename()
                    }

                    ToolCard(
                        title: L("图片转换", "Image Conversion"),
                        subtitle: L("支持 PNG / JPEG / WEBP / TIFF / HEIC 格式互转",
                                    "Convert between PNG / JPEG / WEBP / TIFF / HEIC"),
                        icon: "photo.on.rectangle.angled",
                        color: .purple
                    ) {
                        coordinator.runImageConversionFromToolbox()
                    }

                    ToolCard(
                        title: L("压缩文件", "Compress"),
                        subtitle: L("将选中的文件和文件夹压缩为 ZIP 归档",
                                    "Archive selected files and folders into ZIP"),
                        icon: "archivebox",
                        color: .orange
                    ) {
                        coordinator.runCompressFromToolbox()
                    }

                    ToolCard(
                        title: L("在终端打开", "Open in Terminal"),
                        subtitle: L("在当前目录打开终端窗口",
                                    "Open terminal in the current directory"),
                        icon: "terminal",
                        color: .green
                    ) {
                        coordinator.runOpenTerminalFromToolbox()
                    }
                }

                // Hint
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(L("提示：在 Finder 中选中文件后右键，也可以直接使用这些工具。",
                           "Tip: You can also access these tools by right-clicking files in Finder."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
    }
}

// MARK: - Tool Card Component

private struct ToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isHovered ? color : Color.gray.opacity(0.3))
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 8 : 4, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
