import Foundation

/// 自定义动作的执行类型
public enum CustomActionType: String, Codable, Hashable, Sendable, CaseIterable {
    case shellScript
    case appleScript
    case openApplication

    public var displayName: String {
        switch self {
        case .shellScript: return L("Shell 脚本", "Shell Script")
        case .appleScript: return "AppleScript"
        case .openApplication: return L("打开应用", "Open Application")
        }
    }

    public var iconName: String {
        switch self {
        case .shellScript: return "terminal"
        case .appleScript: return "applescript"
        case .openApplication: return "app.badge.fill"
        }
    }
}

/// 用户自定义的动作定义
public struct CustomAction: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var subtitle: String
    public var systemImageName: String
    public var actionType: CustomActionType
    public var scriptContent: String
    public var section: ActionSection
    public var fileExtensionFilter: [String]
    public var minimumSelectionCount: Int
    public var isEnabled: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "",
        subtitle: String = "",
        systemImageName: String = "bolt",
        actionType: CustomActionType = .shellScript,
        scriptContent: String = "",
        section: ActionSection = .automation,
        fileExtensionFilter: [String] = [],
        minimumSelectionCount: Int = 1,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.actionType = actionType
        self.scriptContent = scriptContent
        self.section = section
        self.fileExtensionFilter = fileExtensionFilter
        self.minimumSelectionCount = minimumSelectionCount
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    /// 将自定义动作转换为标准 ActionDefinition
    public func toActionDefinition() -> ActionDefinition {
        ActionDefinition(
            id: ActionID(rawValue: "custom-\(id.uuidString)"),
            title: name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            systemImageName: systemImageName,
            section: section,
            sortOrder: 200,
            availability: ActionAvailability(
                allowedContextKinds: [.finderSelection, .mixedSelection, .custom],
                minimumSelectionCount: minimumSelectionCount,
                requiresFileItems: true,
                requiredFileExtensions: Set(fileExtensionFilter)
            )
        )
    }
}
