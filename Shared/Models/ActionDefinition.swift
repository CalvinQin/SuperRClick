import Foundation

// MARK: - Locale Detection

/// Lightweight locale helper. Checks App Group defaults first,
/// then falls back to system preferred languages.
public enum SharedLocale {
    public static var isChinese: Bool {
        if let groupDefaults = UserDefaults(suiteName: "group.com.haoqiqin.superrclick"),
           let saved = groupDefaults.string(forKey: "app_selected_language") {
            if saved == "zh-Hans" { return true }
            if saved == "en" { return false }
        }
        guard let preferred = Locale.preferredLanguages.first else { return false }
        return preferred.hasPrefix("zh")
    }
}

/// Inline localization: returns Chinese or English based on current locale.
public func L(_ zh: String, _ en: String) -> String {
    SharedLocale.isChinese ? zh : en
}

// MARK: - Action Section

public enum ActionSection: String, Codable, Hashable, Sendable, Comparable {
    case file
    case newFile
    case text
    case automation
    case system

    public static func < (lhs: ActionSection, rhs: ActionSection) -> Bool {
        order(for: lhs) < order(for: rhs)
    }

    private static func order(for section: ActionSection) -> Int {
        switch section {
        case .file: return 0
        case .newFile: return 1
        case .text: return 2
        case .automation: return 3
        case .system: return 4
        }
    }
}

public struct ActionDefinition: Identifiable, Codable, Hashable, Sendable {
    public var id: ActionID
    public var title: String
    public var subtitle: String?
    public var systemImageName: String?
    public var section: ActionSection
    public var sortOrder: Int
    public var isDestructive: Bool
    public var availability: ActionAvailability

    public init(
        id: ActionID,
        title: String,
        subtitle: String? = nil,
        systemImageName: String? = nil,
        section: ActionSection,
        sortOrder: Int = 0,
        isDestructive: Bool = false,
        availability: ActionAvailability = ActionAvailability()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.section = section
        self.sortOrder = sortOrder
        self.isDestructive = isDestructive
        self.availability = availability
    }

    public func matches(_ context: ActionContext) -> Bool {
        availability.matches(context)
    }
}

