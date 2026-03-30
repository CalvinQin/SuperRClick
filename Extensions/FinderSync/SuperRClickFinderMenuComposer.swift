import AppKit
import Shared

public final class SuperRClickFinderMenuComposer {
    public init() {}

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

        // 1. Add NewFileCatalog
        allDefinitions.append(contentsOf: Shared.NewFileCatalog.all)
        
        // 2. Add Custom Actions from PersistenceState
        do {
            let container = AppGroupContainer(groupIdentifier: "group.com.haoqiqin.superrclick")
            let controller = try container.makePersistenceController()
            let state = controller.loadOrCreateState()
            
            let customDefinitions = state.customActions
                .filter { $0.isEnabled }
                .map { $0.toActionDefinition() }
            
            allDefinitions.append(contentsOf: customDefinitions)
        } catch {
            NSLog("[SuperRClick] Failed to load custom actions: \(error)")
        }

        let availableDefinitions = allDefinitions.filter { definition in
            definition.matches(context.actionContext) && shouldShow(definition: definition, in: context)
        }

        let groupedDefinitions = Dictionary(grouping: availableDefinitions, by: \.section)
        let orderedSections = groupedDefinitions.keys.sorted()

        for (index, section) in orderedSections.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }

            addSectionHeader(for: section, to: menu)

            let definitions = (groupedDefinitions[section] ?? []).sorted(by: definitionSort)
            
            let newFileDefs = definitions.filter { $0.id.rawValue.hasPrefix("new-") }
            let normalDefs = definitions.filter { !$0.id.rawValue.hasPrefix("new-") }
            
            if !newFileDefs.isEmpty {
                let newFileSubMenu = NSMenu(title: SharedLocale.isChinese ? "新建" : "New")
                let newFileItem = NSMenuItem(
                    title: SharedLocale.isChinese ? "新建文件" : "New File",
                    action: nil,
                    keyEquivalent: ""
                )
                newFileItem.image = coloredMenuImage(symbolName: "doc.badge.plus", color: .systemGreen)
                newFileItem.submenu = newFileSubMenu
                menu.addItem(newFileItem)
                
                append(definitions: newFileDefs, to: newFileSubMenu, target: target)
                if !normalDefs.isEmpty {
                    menu.addItem(.separator())
                }
            }

            append(definitions: normalDefs, to: menu, target: target)
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

        menu.addItem(.separator())
        addSectionHeader(for: .system, title: SharedLocale.isChinese ? "工具" : "Utilities", to: menu)
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
                    ("WEBP", "convert-image:webp"),
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
                    subMenu.addItem(fmtItem)
                }
                let parentItem = NSMenuItem(
                    title: definition.title,
                    action: nil,
                    keyEquivalent: ""
                )
                parentItem.image = menuImage(for: definition)
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
            item.image = menuImage(for: definition)
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

    /// Returns a colored SF Symbol image for menu items.
    /// Uses palette rendering with a specific accent color so icons are
    /// visually distinct in both light and dark mode context menus.
    private func menuImage(for definition: ActionDefinition) -> NSImage? {
        guard let symbolName = definition.systemImageName else {
            return nil
        }

        let color = iconColor(for: definition.section, actionId: definition.id.rawValue)
        return coloredMenuImage(symbolName: symbolName, color: color)
    }

    private func coloredMenuImage(symbolName: String, color: NSColor) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        let coloredImage = baseImage.withSymbolConfiguration(config)
        coloredImage?.isTemplate = false
        return coloredImage
    }

    /// Maps section/action to a distinct color for visual categorization.
    private func iconColor(for section: ActionSection, actionId: String) -> NSColor {
        switch section {
        case .file:
            // Give specific file actions distinct colors
            switch actionId {
            case "compress-items": return .systemOrange
            case "convert-image": return .systemPurple
            case "batch-rename": return .systemTeal
            default: return .systemBlue
            }
        case .newFile:
            return .systemGreen
        case .text:
            return .systemIndigo
        case .automation:
            return .systemOrange
        case .system:
            return .systemGray
        }
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
