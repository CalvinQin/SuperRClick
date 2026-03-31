import Shared
import SwiftUI

struct ToolsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("工具箱", "Toolbox"))
                        .font(.largeTitle.weight(.bold))

                    Text(L("常用文件操作工具，也可通过 Finder 右键菜单使用。",
                           "Frequently used file tools. Also available via Finder right-click menu."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
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
                        icon: "archivebox.fill",
                        color: .orange
                    ) {
                        coordinator.runCompressFromToolbox()
                    }

                    ToolCard(
                        title: L("在终端打开", "Open in Terminal"),
                        subtitle: L("在当前目录打开终端窗口",
                                    "Open terminal in the current directory"),
                        icon: "terminal.fill",
                        color: .green
                    ) {
                        coordinator.runOpenTerminalFromToolbox()
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.callout)
                    Text(L("提示：在 Finder 中选中文件后右键，也可以直接使用这些工具。",
                           "Tip: You can also access these tools by right-clicking files in Finder."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 0.5)
                )
            }
            .padding(28)
            .padding(.top, 8)
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
                        .font(.title3.weight(.medium))
                        .foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isHovered ? color : Color.gray.opacity(0.3))
                        .padding(6)
                        .background(isHovered ? color.opacity(0.08) : Color.clear, in: Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(
                        color: isHovered ? color.opacity(0.1) : .black.opacity(0.03),
                        radius: isHovered ? 10 : 4,
                        y: isHovered ? 4 : 2
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isHovered ? color.opacity(0.3) : Color(nsColor: .separatorColor).opacity(0.25),
                        lineWidth: isHovered ? 1.2 : 0.5
                    )
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
