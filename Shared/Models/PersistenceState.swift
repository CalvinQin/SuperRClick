import Foundation

public enum InvocationOutcome: String, Codable, Hashable, Sendable {
    case success
    case blocked
    case failure
    case missingHandler
}

public struct ActionInvocationRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var actionID: ActionID
    public var occurredAt: Date
    public var context: ContextSnapshot
    public var outcome: InvocationOutcome
    public var note: String?

    public init(
        id: UUID = UUID(),
        actionID: ActionID,
        occurredAt: Date = Date(),
        context: ContextSnapshot,
        outcome: InvocationOutcome,
        note: String? = nil
    ) {
        self.id = id
        self.actionID = actionID
        self.occurredAt = occurredAt
        self.context = context
        self.outcome = outcome
        self.note = note
    }
}

public struct PinnedAction: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var actionID: ActionID
    public var order: Int
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        actionID: ActionID,
        order: Int = 0,
        isFavorite: Bool = true
    ) {
        self.id = id
        self.actionID = actionID
        self.order = order
        self.isFavorite = isFavorite
    }
}

public struct WorkspaceProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var rootURL: URL
    public var pinnedActionIDs: [ActionID]
    public var visibilityRuleIDs: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        rootURL: URL,
        pinnedActionIDs: [ActionID] = [],
        visibilityRuleIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.rootURL = rootURL
        self.pinnedActionIDs = pinnedActionIDs
        self.visibilityRuleIDs = visibilityRuleIDs
    }
}

public enum MonitoredFolderPreset: String, Codable, Hashable, Sendable, CaseIterable {
    case desktop
    case documents
    case downloads
    case custom
}

public struct MonitoredFolder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var url: URL
    public var preset: MonitoredFolderPreset
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        preset: MonitoredFolderPreset = .custom,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.preset = preset
        self.isEnabled = isEnabled
    }
}

public struct PersistenceState: Codable, Hashable, Sendable {
    public var pinnedActions: [PinnedAction]
    public var visibilityRules: [VisibilityRule]
    public var workspaceProfiles: [WorkspaceProfile]
    public var monitoredFolders: [MonitoredFolder]
    public var actionHistory: [ActionInvocationRecord]
    public var customActions: [CustomAction]

    public init(
        pinnedActions: [PinnedAction] = [],
        visibilityRules: [VisibilityRule] = [],
        workspaceProfiles: [WorkspaceProfile] = [],
        monitoredFolders: [MonitoredFolder] = [],
        actionHistory: [ActionInvocationRecord] = [],
        customActions: [CustomAction] = []
    ) {
        self.pinnedActions = pinnedActions
        self.visibilityRules = visibilityRules
        self.workspaceProfiles = workspaceProfiles
        self.monitoredFolders = monitoredFolders
        self.actionHistory = actionHistory
        self.customActions = customActions
    }

    enum CodingKeys: String, CodingKey {
        case pinnedActions
        case visibilityRules
        case workspaceProfiles
        case monitoredFolders
        case actionHistory
        case customActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinnedActions = try container.decodeIfPresent([PinnedAction].self, forKey: .pinnedActions) ?? []
        visibilityRules = try container.decodeIfPresent([VisibilityRule].self, forKey: .visibilityRules) ?? []
        workspaceProfiles = try container.decodeIfPresent([WorkspaceProfile].self, forKey: .workspaceProfiles) ?? []
        monitoredFolders = try container.decodeIfPresent([MonitoredFolder].self, forKey: .monitoredFolders) ?? []
        actionHistory = try container.decodeIfPresent([ActionInvocationRecord].self, forKey: .actionHistory) ?? []
        customActions = try container.decodeIfPresent([CustomAction].self, forKey: .customActions) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pinnedActions, forKey: .pinnedActions)
        try container.encode(visibilityRules, forKey: .visibilityRules)
        try container.encode(workspaceProfiles, forKey: .workspaceProfiles)
        try container.encode(monitoredFolders, forKey: .monitoredFolders)
        try container.encode(actionHistory, forKey: .actionHistory)
        try container.encode(customActions, forKey: .customActions)
    }
}
