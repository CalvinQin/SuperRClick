import AppKit
import Shared

public final class SuperRClickFinderMenuComposer {
    private let stateProvider: () throws -> PersistenceState

    public convenience init() {
        self.init(stateProvider: {
            let container = AppGroupContainer(groupIdentifier: "group.com.haoqiqin.superrclick")
            return try container.makePersistenceController().loadOrCreateState()
        })
    }

    /// Allows previews and offline checks to provide state without opening App Group storage.
    public init(stateProvider: @escaping () throws -> PersistenceState) {
        self.stateProvider = stateProvider
    }

    public func makeMenu(for context: SuperRClickFinderContext, target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: "Super RClick")

        switch context.surface {
        case .toolbar:
            appendToolbarActions(for: context, to: menu, target: target)
        default:
            appendSharedActions(for: context, to: menu, target: target)
            appendFinderUtilities(for: context, to: menu, target: target)
        }

        return menu
    }

    private func appendSharedActions(for context: SuperRClickFinderContext, to menu: NSMenu, target: AnyObject) {
        var allDefinitions = BuiltInActionCatalog.all
        var visibilityRules: [VisibilityRule] = []

        // 1. Add NewFileCatalog
        allDefinitions.append(contentsOf: Shared.NewFileCatalog.all)
        
        // 2. Add Custom Actions from PersistenceState
        do {
            let state = try stateProvider()
            visibilityRules = state.visibilityRules
            
            let customDefinitions = state.customActions
                .filter { $0.isEnabled }
                .map { $0.toActionDefinition() }
            
            allDefinitions.append(contentsOf: customDefinitions)
            
            if !state.aiConfig.isEnabled {
                allDefinitions.removeAll { def in
                    def.section == .ai && def.id != AIActionCatalog.ocrExtract && def.id != AIActionCatalog.removeBackground
                }
            }
        } catch {
            NSLog("[SuperRClick] Failed to load menu configuration: \(error)")
        }

        let actionContext = context.actionContext
        let availableDefinitions = allDefinitions.filter { definition in
            ActionEngine.isVisible(definition, in: actionContext, visibilityRules: visibilityRules)
                && shouldShow(definition: definition, in: context)
        }

        let groupedDefinitions = Dictionary(grouping: availableDefinitions, by: \.section)
        let orderedSections = groupedDefinitions.keys.sorted()

        for section in orderedSections {
            let definitions = (groupedDefinitions[section] ?? []).sorted(by: definitionSort)
            
            if section == .newFile {
                let newFileSubMenu = NSMenu(title: SharedLocale.isChinese ? "新建" : "New")
                let newFileItem = NSMenuItem(
                    title: SharedLocale.isChinese ? "新建文件" : "New File",
                    action: nil,
                    keyEquivalent: ""
                )
                Self.setImage(Self.image(named: "doc.badge.plus"), on: newFileItem)
                newFileItem.submenu = newFileSubMenu
                menu.addItem(newFileItem)
                
                append(definitions: definitions, to: newFileSubMenu, target: target)
            } else if section == .ai {
                let aiSubMenu = NSMenu(title: "AI")
                let aiItem = NSMenuItem(
                    title: SharedLocale.isChinese ? "AI 工具" : "AI Actions",
                    action: nil,
                    keyEquivalent: ""
                )
                Self.setImage(Self.image(named: "sparkles"), on: aiItem)
                aiItem.submenu = aiSubMenu
                menu.addItem(aiItem)
                
                append(definitions: definitions, to: aiSubMenu, target: target)
            } else {
                append(definitions: definitions, to: menu, target: target)
            }
        }
    }

    private func appendFinderUtilities(for context: SuperRClickFinderContext, to menu: NSMenu, target: AnyObject) {
        let utilities: [FinderUtilityAction] = [
            .revealInFinder,
            .openSuperRClickPreferences
        ]

        let actionableUtilities = utilities.filter { utility in
            utility.isEnabled(for: context)
        }

        guard !actionableUtilities.isEmpty else {
            return
        }

        append(utilities: actionableUtilities, to: menu, target: target, context: context)
    }

    private func appendToolbarActions(
        for context: SuperRClickFinderContext,
        to menu: NSMenu,
        target: AnyObject
    ) {
        let actions: [FinderUtilityAction] = [
            .openSuperRClickPreferences,
            .refreshFinderTargets
        ]

        addSectionHeader(for: .system, title: SharedLocale.isChinese ? "菜单栏" : "Menu Bar", to: menu)
        append(utilities: actions, to: menu, target: target, context: nil)
    }

    private func append(definitions: [ActionDefinition], to menu: NSMenu, target: AnyObject) {
        for definition in definitions {
            // For image conversion, create a submenu with format options
            if definition.id == BuiltInActionCatalog.convertImage.id {
                let subMenu = NSMenu(title: definition.title)
                let formats = [
                    ("PNG", "convert-image:png"),
                    ("JPEG", "convert-image:jpeg"),
                    ("TIFF", "convert-image:tiff"),
                    ("HEIC", "convert-image:heic"),
                ]
                for (label, actionID) in formats {
                    let fmtItem = NSMenuItem(
                        title: label,
                        action: #selector(SuperRClickFinderSync.handleMenuAction(_:)),
                        keyEquivalent: ""
                    )
                    fmtItem.target = target
                    fmtItem.representedObject = actionID
                    Self.setImage(Self.image(named: "photo"), on: fmtItem)
                    subMenu.addItem(fmtItem)
                }
                let parentItem = NSMenuItem(
                    title: definition.title,
                    action: nil,
                    keyEquivalent: ""
                )
                Self.setImage(menuImage(for: definition), on: parentItem)
                parentItem.submenu = subMenu
                menu.addItem(parentItem)
                continue
            }

            let item = NSMenuItem(
                title: definition.title,
                action: #selector(SuperRClickFinderSync.handleMenuAction(_:)),
                keyEquivalent: keyEquivalent(for: definition)
            )
            item.target = target
            item.isEnabled = true
            item.representedObject = definition.id.rawValue
            Self.setImage(menuImage(for: definition), on: item)
            menu.addItem(item)
        }
    }

    private func append(
        utilities: [FinderUtilityAction],
        to menu: NSMenu,
        target: AnyObject,
        context: SuperRClickFinderContext?
    ) {
        for utility in utilities {
            let item = NSMenuItem(
                title: utility.title,
                action: #selector(SuperRClickFinderSync.handleMenuAction(_:)),
                keyEquivalent: utility.keyEquivalent
            )
            item.target = target
            item.isEnabled = context.map { utility.isEnabled(for: $0) } ?? true
            item.representedObject = utility.rawValue
            Self.setImage(Self.image(named: utility.iconName), on: item)
            menu.addItem(item)
        }
    }

    private func shouldShow(definition: ActionDefinition, in context: SuperRClickFinderContext) -> Bool {
        if context.isContainerBackground && !context.hasSelection && definition.id == BuiltInActionCatalog.batchRename.id {
            return false
        }

        return true
    }

    private func addSectionHeader(for section: ActionSection, title: String? = nil, to menu: NSMenu) {
        let headerTitle = title ?? self.title(for: section)
        let item = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.isHidden = false
        menu.addItem(item)
    }

    private func title(for section: ActionSection) -> String {
        switch section {
        case .file:
            return SharedLocale.isChinese ? "文件" : "File"
        case .newFile:
            return SharedLocale.isChinese ? "新建" : "New"
        case .text:
            return SharedLocale.isChinese ? "文本" : "Text"
        case .ai:
            return SharedLocale.isChinese ? "AI 工具" : "AI Actions"
        case .automation:
            return SharedLocale.isChinese ? "自动化" : "Automation"
        case .system:
            return SharedLocale.isChinese ? "系统" : "System"
        }
    }

    private func definitionSort(_ lhs: ActionDefinition, _ rhs: ActionDefinition) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func keyEquivalent(for definition: ActionDefinition) -> String {
        switch definition.id.rawValue {
        case BuiltInActionCatalog.copyFullPath.id.rawValue:
            return "c"
        default:
            return ""
        }
    }

    // MARK: - Icon Helpers

    /// FinderSync's synchronous Objective-C callbacks are not actor-isolated.
    /// NSImage is transferable; draw it on MainActor without transferring NSMenu.
    static func image(named name: String, size: CGFloat = 16) -> NSImage {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { RClickIcon.image(named: name, size: size) }
        }
        return DispatchQueue.main.sync { RClickIcon.image(named: name, size: size) }
    }

    static func setImage(_ image: NSImage?, on item: NSMenuItem) {
        item.image = image
        if #available(macOS 27.0, *), image != nil {
            // These original glyphs identify actions; preserve them under macOS
            // 27's automatic menu-image policy. Earlier systems retain defaults.
            item.preferredImageVisibility = .visible
        }
    }

    private func menuImage(for definition: ActionDefinition) -> NSImage? {
        guard let symbolName = definition.systemImageName else { return nil }
        return Self.image(named: symbolName, size: 16)
    }

    private enum FinderUtilityAction: String {
        case revealInFinder = "utility:reveal-in-finder"
        case openSuperRClickPreferences = "utility:open-preferences"
        case refreshFinderTargets = "utility:refresh-targets"

        var title: String {
            switch self {
            case .revealInFinder:
                return SharedLocale.isChinese ? "在访达中显示" : "Reveal in Finder"
            case .openSuperRClickPreferences:
                return SharedLocale.isChinese ? "打开 Super RClick" : "Open Super RClick"
            case .refreshFinderTargets:
                return SharedLocale.isChinese ? "刷新监控目录" : "Refresh Targets"
            }
        }

        var iconName: String {
            switch self {
            case .revealInFinder: return "folder"
            case .openSuperRClickPreferences: return "gearshape"
            case .refreshFinderTargets: return "arrow.clockwise"
            }
        }

        var keyEquivalent: String {
            switch self {
            case .revealInFinder:
                return "r"
            case .openSuperRClickPreferences, .refreshFinderTargets:
                return ""
            }
        }

        func isEnabled(for context: SuperRClickFinderContext) -> Bool {
            switch self {
            case .revealInFinder:
                return !context.effectiveSelectionURLs.isEmpty
            case .openSuperRClickPreferences, .refreshFinderTargets:
                return true
            }
        }
    }
}
