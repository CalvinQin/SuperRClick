import Shared
import SwiftUI

struct ActionSymbol: View {
    let name: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}

struct ActionStatusBanner: View {
    let status: AppCoordinator.StatusBanner
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.iconName)
                .foregroundStyle(status.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(status.title).font(.callout.weight(.semibold))
                if let detail = status.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
            }
            Spacer(minLength: 12)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("关闭状态提示", "Dismiss status"))
            .help(L("关闭状态提示", "Dismiss status"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("operation.status")
    }
}

extension ActionSection {
    var displayName: String {
        switch self {
        case .file: L("文件操作", "File actions")
        case .newFile: L("文件模板", "File templates")
        case .text: L("文本处理", "Text")
        case .automation: L("自动化", "Automation")
        case .system: L("系统", "System")
        case .ai: L("AI 工具", "AI tools")
        }
    }

    var tint: Color {
        switch self {
        case .file: .blue
        case .newFile: .teal
        case .text: .indigo
        case .automation: .orange
        case .system: .secondary
        case .ai: .purple
        }
    }
}
