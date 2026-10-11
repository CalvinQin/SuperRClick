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
    public enum ValidationError: LocalizedError, Equatable, Sendable {
        case emptyName
        case emptyContent(CustomActionType)
        case invalidFileExtension(String)
        case invalidMinimumSelectionCount

        public var errorDescription: String? {
            switch self {
            case .emptyName:
                return L("请输入动作名称。", "Enter an action name.")
            case .emptyContent(.shellScript):
                return L("请输入 Shell 脚本。", "Enter a shell script.")
            case .emptyContent(.appleScript):
                return L("请输入 AppleScript 脚本。", "Enter an AppleScript.")
            case .emptyContent(.openApplication):
                return L("请输入要打开的应用名称或路径。", "Enter the application name or path to open.")
            case let .invalidFileExtension(value):
                return L(
                    "扩展名“\(value)”无效。请使用 txt 或 pdf 等扩展名，不含空格、路径或通配符。",
                    "“\(value)” is not a valid extension. Use extensions such as txt or pdf without spaces, paths, or wildcards."
                )
            case .invalidMinimumSelectionCount:
                return L("最少选择数量必须介于 1 到 100 之间。", "The minimum selection count must be between 1 and 100.")
            }
        }
    }

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

    /// Parses the comma-separated editor field without silently removing invalid extensions.
    public static func parseFileExtensions(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Returns a normalized copy suitable for saving, preserving the original script verbatim.
    public func validated() throws -> CustomAction {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.name.isEmpty else {
            throw ValidationError.emptyName
        }
        guard !scriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyContent(actionType)
        }
        guard (1...100).contains(minimumSelectionCount) else {
            throw ValidationError.invalidMinimumSelectionCount
        }

        let invalidCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "/\\*?[],，"))
        var seenExtensions = Set<String>()
        result.fileExtensionFilter = try fileExtensionFilter.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let normalized = String(trimmed.drop(while: { $0 == "." })).lowercased()
            guard !normalized.isEmpty, normalized.rangeOfCharacter(from: invalidCharacters) == nil else {
                throw ValidationError.invalidFileExtension(value)
            }
            return seenExtensions.insert(normalized).inserted ? normalized : nil
        }

        return result
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
