import Foundation

public enum AIActionCatalog {
    public static let smartRename: ActionID = "ai.smartRename"
    public static let autoTag: ActionID = "ai.autoTag"
    public static let ocrExtract: ActionID = "ai.ocrExtract"
    public static let removeBackground: ActionID = "ai.removeBackground"

    public static let all: [ActionDefinition] = [
        ActionDefinition(
            id: smartRename,
            title: L("AI 图片重命名", "AI Image Rename"),
            subtitle: L("根据图片内容生成描述性名称", "Generate descriptive name based on image content"),
            systemImageName: "character.cursor.ibeam",
            section: .ai,
            sortOrder: 0,
            availability: ActionAvailability(
                minimumSelectionCount: 1,
                maximumSelectionCount: 10,
                requiresFileItems: true,
                requiredFileExtensions: ["png", "jpg", "jpeg", "tiff", "heic", "webp", "gif", "bmp"]
            )
        ),
        ActionDefinition(
            id: autoTag,
            title: L("AI 智能标签", "AI Auto Tag"),
            subtitle: L("分析内容并自动添加 Finder 标签", "Analyze content and set Finder tags"),
            systemImageName: "tag.fill",
            section: .ai,
            sortOrder: 3,
            availability: ActionAvailability(
                minimumSelectionCount: 1,
                maximumSelectionCount: 10,
                requiresFileItems: true
            )
        ),
        ActionDefinition(
            id: ocrExtract,
            title: L("提取图片文字 (本地 OCR)", "Extract Text (Local OCR)"),
            subtitle: L("使用本地引擎从图片提取文字", "Extract text using on-device OCR"),
            systemImageName: "text.viewfinder",
            section: .ai,
            sortOrder: 4,
            availability: ActionAvailability(
                minimumSelectionCount: 1,
                maximumSelectionCount: 10,
                requiresFileItems: true,
                requiredFileExtensions: ["png", "jpg", "jpeg", "tiff", "heic", "webp"]
            )
        ),
        ActionDefinition(
            id: removeBackground,
            title: L("移除图片背景 (本地 AI)", "Remove Background (Local AI)"),
            subtitle: L("使用本地引擎移除主体背景", "Remove background from subject"),
            systemImageName: "person.crop.circle.badge.minus",
            section: .ai,
            sortOrder: 5,
            availability: ActionAvailability(
                minimumSelectionCount: 1,
                maximumSelectionCount: 10,
                requiresFileItems: true,
                requiredFileExtensions: ["png", "jpg", "jpeg", "tiff", "heic", "webp"]
            )
        )
    ]
}
