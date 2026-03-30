import AppKit
import Shared

@MainActor
final class DesktopBridgeMenuBuilder {
    private let coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    func makeMenu(for context: ActionContext) -> NSMenu {
        let menu = NSMenu(title: "Super RClick Desktop Bridge")
        
        var allDefinitions = BuiltInActionCatalog.all
        allDefinitions.append(contentsOf: NewFileCatalog.all)
        
        let customDefinitions = coordinator.persistenceState.customActions
            .filter { $0.isEnabled }
            .map { $0.toActionDefinition() }
        allDefinitions.append(contentsOf: customDefinitions)

        let availableDefinitions = allDefinitions.filter { definition in
            definition.matches(context) && !coordinator.isActionHidden(definition)
        }

        let groupedDefinitions = Dictionary(grouping: availableDefinitions, by: \.section)
        let orderedSections = groupedDefinitions.keys.sorted()

        for (index, section) in orderedSections.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }

            let definitions = (groupedDefinitions[section] ?? []).sorted(by: { $0.title < $1.title })
            
            let newFileDefs = definitions.filter { $0.id.rawValue.hasPrefix("new-") }
            let normalDefs = definitions.filter { !$0.id.rawValue.hasPrefix("new-") }
            
            if !newFileDefs.isEmpty {
                let newFileSubMenu = NSMenu(title: "新建 (New)")
                let newFileItem = NSMenuItem(title: "新建文件...", action: nil, keyEquivalent: "")
                if let image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil) {
                    newFileItem.image = image
                }
                newFileItem.submenu = newFileSubMenu
                menu.addItem(newFileItem)
                
                for def in newFileDefs {
                    newFileSubMenu.addItem(makeMenuItem(for: def, context: context))
                }
                
                if !normalDefs.isEmpty {
                    menu.addItem(.separator())
                }
            }

            for def in normalDefs {
                menu.addItem(makeMenuItem(for: def, context: context))
            }
        }
        
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Super RClick 设置...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        if let icon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
            settingsItem.image = icon
        }
        menu.addItem(settingsItem)
        
        return menu
    }
    
    private func makeMenuItem(for definition: ActionDefinition, context: ActionContext) -> NSMenuItem {
        let item = NSMenuItem(title: definition.title, action: #selector(handleAction(_:)), keyEquivalent: "")
        item.target = self
        // Store the definition ID string in representedObject
        item.representedObject = ActionPayload(actionID: definition.id, context: context)
        
        if let symbolName = definition.systemImageName, let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            item.image = image
        }
        
        return item
    }
    
    @objc private func handleAction(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ActionPayload else { return }
        if let definition = (BuiltInActionCatalog.all + NewFileCatalog.all).first(where: { $0.id == payload.actionID }) {
            coordinator.sampleContext = payload.context
             // update sample Context before running? Or just pass it. Wait, run() uses sampleContext in AppCoordinator.
            coordinator.sampleContext = payload.context
            coordinator.run(definition)
        } else if let custom = coordinator.persistenceState.customActions.first(where: { $0.id.uuidString == payload.actionID.rawValue }) {
            coordinator.sampleContext = payload.context
            coordinator.run(custom.toActionDefinition())
        }
    }
    
    @objc private func openSettings(_ sender: NSMenuItem) {
        // Just bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ActionPayload {
    let actionID: ActionID
    let context: ActionContext
}
