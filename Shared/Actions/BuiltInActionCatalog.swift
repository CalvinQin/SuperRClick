import Foundation

public enum BuiltInActionCatalog {
    public static var copyFullPath: ActionDefinition {
        ActionDefinition(
            id: "copy-full-path",
            title: SharedLocale.isChinese ? "拷贝完整路径" : "Copy Full Path",
            subtitle: SharedLocale.isChinese ? "将文件绝对路径复制到剪贴板" : "Copy absolute file paths to the clipboard",
            systemImageName: "doc.on.doc",
            section: .file,
            sortOrder: 10,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var copyPOSIXPath: ActionDefinition {
        ActionDefinition(
            id: "copy-posix-path",
            title: SharedLocale.isChinese ? "拷贝 POSIX 路径" : "Copy POSIX Path",
            subtitle: SharedLocale.isChinese ? "拷贝标准 POSIX 路径" : "Copy clean POSIX paths",
            systemImageName: "doc.on.clipboard",
            section: .file,
            sortOrder: 20,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var copyShellEscapedPath: ActionDefinition {
        ActionDefinition(
            id: "copy-shell-escaped-path",
            title: SharedLocale.isChinese ? "拷贝 Shell 路径" : "Copy Shell Path",
            subtitle: SharedLocale.isChinese ? "拷贝适用于终端的转义路径" : "Copy shell-escaped paths for Terminal",
            systemImageName: "terminal",
            section: .file,
            sortOrder: 30,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var openTerminalHere: ActionDefinition {
        ActionDefinition(
            id: "open-terminal-here",
            title: SharedLocale.isChinese ? "在终端中打开" : "Open Terminal Here",
            subtitle: SharedLocale.isChinese ? "在所选位置打开终端窗口" : "Open a Terminal window at the selected location",
            systemImageName: "terminal.fill",
            section: .system,
            sortOrder: 40,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var compressItems: ActionDefinition {
        ActionDefinition(
            id: "compress-items",
            title: SharedLocale.isChinese ? "压缩" : "Compress",
            subtitle: SharedLocale.isChinese ? "将选中项创建为压缩包" : "Create an archive from the current selection",
            systemImageName: "archivebox",
            section: .file,
            sortOrder: 50,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var batchRename: ActionDefinition {
        ActionDefinition(
            id: "batch-rename",
            title: SharedLocale.isChinese ? "批量重命名" : "Batch Rename",
            subtitle: SharedLocale.isChinese ? "一步重命名多个文件" : "Rename multiple files in one step",
            systemImageName: "pencil.and.list.clipboard",
            section: .file,
            sortOrder: 60,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true
            )
        )
    }

    public static var convertImage: ActionDefinition {
        ActionDefinition(
            id: "convert-image",
            title: SharedLocale.isChinese ? "转换图像" : "Convert Image",
            subtitle: SharedLocale.isChinese ? "将图片转换为其他格式" : "Convert images to another format",
            systemImageName: "photo",
            section: .file,
            sortOrder: 70,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: 1,
                requiresFileItems: true,
                requiredFileExtensions: ["png", "jpg", "jpeg", "heic", "tiff", "webp", "gif"]
            )
        )
    }

    public static var copySelectedText: ActionDefinition {
        ActionDefinition(
            id: "copy-selected-text",
            title: SharedLocale.isChinese ? "拷贝选中文本" : "Copy Selected Text",
            subtitle: SharedLocale.isChinese ? "仅拷贝选中的纯文本内容" : "Copy selected text without formatting",
            systemImageName: "doc.on.doc.fill",
            section: .text,
            sortOrder: 80,
            availability: ActionAvailability(
                allowedContextKinds: [.textSelection, .mixedSelection],
                minimumSelectionCount: 1,
                requiresTextSelection: true
            )
        )
    }

    public static var fileActions: [ActionDefinition] {
        [
            copyFullPath,
            copyPOSIXPath,
            copyShellEscapedPath,
            openTerminalHere,
            compressItems,
            batchRename,
            convertImage
        ]
    }

    public static var textActions: [ActionDefinition] {
        [copySelectedText]
    }

    public static var all: [ActionDefinition] {
        fileActions + textActions + AIActionCatalog.all
    }

    public static func definition(for actionID: ActionID) -> ActionDefinition? {
        all.first(where: { $0.id == actionID })
    }
}
