import Foundation

public enum ActionExecutionResult: Equatable, Sendable {
    case completed(message: String? = nil)
    case blocked(reason: String)
    case failed(reason: String, recoverable: Bool)
    case missingHandler(actionID: ActionID)
}

public typealias ActionExecutionHandler = @Sendable (ActionContext) async -> ActionExecutionResult

public actor ActionEngine {
    private var definitionsByID: [ActionID: ActionDefinition]
    private var handlers: [ActionID: ActionExecutionHandler]
    private var visibilityRules: [VisibilityRule]

    public init(
        definitions: [ActionDefinition] = BuiltInActionCatalog.all,
        visibilityRules: [VisibilityRule] = []
    ) {
        self.definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        self.handlers = [:]
        self.visibilityRules = visibilityRules
    }

    public func setVisibilityRules(_ rules: [VisibilityRule]) {
        visibilityRules = rules
    }

    /// Re-read action definitions from the catalog (e.g. after language change).
    public func reloadDefinitions(_ definitions: [ActionDefinition] = BuiltInActionCatalog.all) {
        self.definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    public func definition(for actionID: ActionID) -> ActionDefinition? {
        definitionsByID[actionID]
    }

    public func allDefinitions() -> [ActionDefinition] {
        definitionsByID.values.sorted(by: Self.definitionSort)
    }

    public func actionIDs(for context: ActionContext) -> [ActionID] {
        availableActions(for: context).map(\.id)
    }

    public func availableActions(for context: ActionContext) -> [ActionDefinition] {
        allDefinitions().filter { definition in
            isVisible(definition, in: context)
        }
    }

    public func groupedAvailableActions(for context: ActionContext) -> [(section: ActionSection, actions: [ActionDefinition])] {
        let actions = availableActions(for: context)
        let sections = Dictionary(grouping: actions, by: \.section)

        return sections.keys.sorted().map { section in
            let actionsInSection = (sections[section] ?? []).sorted(by: Self.definitionSort)
            return (section: section, actions: actionsInSection)
        }
    }

    public func registerHandler(
        for actionID: ActionID,
        handler: @escaping ActionExecutionHandler
    ) {
        handlers[actionID] = handler
    }

    public func execute(actionID: ActionID, context: ActionContext) async -> ActionExecutionResult {
        guard let definition = definitionsByID[actionID] else {
            return .missingHandler(actionID: actionID)
        }

        guard isVisible(definition, in: context) else {
            return .blocked(reason: "Action is not available for the current context.")
        }

        guard let handler = handlers[actionID] else {
            return .missingHandler(actionID: actionID)
        }

        return await handler(context)
    }

    private func isVisible(_ definition: ActionDefinition, in context: ActionContext) -> Bool {
        guard definition.matches(context) else {
            return false
        }

        let relevantRules = visibilityRules.filter { rule in
            rule.actionID == nil || rule.actionID == definition.id
        }

        if relevantRules.contains(where: { $0.mode == .exclude && $0.matches(actionID: definition.id, context: context) }) {
            return false
        }

        let includeRules = relevantRules.filter { $0.mode == .include }
        guard !includeRules.isEmpty else {
            return true
        }

        return includeRules.contains { $0.matches(actionID: definition.id, context: context) }
    }

    private static func definitionSort(_ lhs: ActionDefinition, _ rhs: ActionDefinition) -> Bool {
        if lhs.section != rhs.section {
            return lhs.section < rhs.section
        }

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

