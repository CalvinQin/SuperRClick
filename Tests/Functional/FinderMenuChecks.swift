import AppKit
import Foundation
import Shared

// The production composer only needs this selector. No FIFinderSync instance is
// constructed, so this executable cannot register or enable an extension.
final class SuperRClickFinderSync: NSObject {
    @objc func handleMenuAction(_ sender: NSMenuItem) {}
}

@main
@MainActor
enum FinderMenuChecks {
    struct Check: Codable {
        let name: String
        let status: String
        let detail: String
    }

    static func main() throws {
        let fixtureRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let folder = fixtureRoot.appendingPathComponent("selected folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let textFile = fixtureRoot.appendingPathComponent("notes.txt")
        let imageFile = fixtureRoot.appendingPathComponent("image.png")
        try Data("Fixture only".utf8).write(to: textFile)
        try Data("Menu checks inspect extensions, not pixels".utf8).write(to: imageFile)

        let target = SuperRClickFinderSync()
        var state = PersistenceState()
        var loadCount = 0
        let composer = SuperRClickFinderMenuComposer(stateProvider: {
            loadCount += 1
            return state
        })
        var checks: [Check] = []
        func check(_ name: String, _ passed: Bool, _ detail: String = "") {
            checks.append(Check(name: name, status: passed ? "PASS" : "FAIL", detail: detail))
            print("\(passed ? "PASS" : "FAIL") \(name)\(detail.isEmpty ? "" : ": " + detail)")
        }
        func context(_ kind: SuperRClickFinderMenuKind = .items, target: URL? = nil, selection: [URL] = []) -> SuperRClickFinderContext {
            SuperRClickFinderContext(menuKind: kind, targetedURL: target, selectedItemURLs: selection, monitoredDirectoryURLs: [fixtureRoot])
        }
        func menu(_ context: SuperRClickFinderContext) -> NSMenu {
            composer.makeMenu(for: context, target: target)
        }
        func allItems(_ menu: NSMenu) -> [NSMenuItem] {
            menu.items.flatMap { item in [item] + (item.submenu.map(allItems) ?? []) }
        }
        func ids(_ menu: NSMenu) -> Set<String> {
            Set(allItems(menu).compactMap { $0.representedObject as? String })
        }
        func hasEmptySubmenu(_ menu: NSMenu) -> Bool {
            allItems(menu).contains { $0.submenu?.numberOfItems == 0 }
        }
        let txt = context(selection: [textFile])
        let png = context(selection: [imageFile])
        let mixed = context(selection: [textFile, imageFile])
        let folderSelection = context(selection: [folder])
        let folderBackground = context(.container, target: folder)
        let desktopBackground = context(.container, target: RealUserDirectories.desktop())
        let sidebar = context(.sidebar, target: folder)
        let toolbar = context(.toolbar, target: folder)
        let empty = context()

        let surfaces: [(String, SuperRClickFinderContext, SuperRClickFinderSurface)] = [
            ("file selection", txt, .items), ("directory selection", folderSelection, .items),
            ("mixed selection", mixed, .items), ("folder background", folderBackground, .folderBackground),
            ("desktop background", desktopBackground, .desktopBackground), ("sidebar", sidebar, .sidebar),
            ("toolbar", toolbar, .toolbar), ("empty selection", empty, .items)
        ]
        for (name, context, surface) in surfaces {
            let built = menu(context)
            let itemIDs = ids(built)
            check("\(name): resolves surface", context.surface == surface)
            check("\(name): preferences reachable", itemIDs.contains("utility:open-preferences"))
            check("\(name): no empty submenu", !hasEmptySubmenu(built))
            check("\(name): no duplicate action ID", allItems(built).compactMap { $0.representedObject as? String }.count == itemIDs.count)
            let leaves = allItems(built).filter { $0.representedObject != nil }
            check("\(name): actions retain selector and target", leaves.allSatisfy {
                $0.action == #selector(SuperRClickFinderSync.handleMenuAction(_:)) && $0.target === target && $0.isEnabled
            })
            check("\(name): original template icons have menu dimensions", leaves.allSatisfy {
                $0.image?.isTemplate == true && $0.image?.size == NSSize(width: 16, height: 16)
            })
            if #available(macOS 27.0, *) {
                check("\(name): macOS 27 preserves action icons", allItems(built).filter { $0.image != nil }.allSatisfy {
                    $0.preferredImageVisibility == .visible
                })
            }
        }
        check("directory selection: batch rename available", ids(menu(folderSelection)).contains("batch-rename"))
        check("folder background: batch rename hidden", !ids(menu(folderBackground)).contains("batch-rename"))
        check("desktop background: batch rename hidden", !ids(menu(desktopBackground)).contains("batch-rename"))
        check("empty selection: no file operations", !ids(menu(empty)).contains("compress-items"))
        check("toolbar: only utility actions", ids(menu(toolbar)) == ["utility:open-preferences", "utility:refresh-targets"])

        let pngIDs = ids(menu(png))
        let formats: Set<String> = ["convert-image:png", "convert-image:jpeg", "convert-image:tiff", "convert-image:heic"]
        check("image conversion: all four dynamic formats", formats.isSubset(of: pngIDs))
        check("image conversion: absent for text", formats.isDisjoint(with: ids(menu(txt))))
        check("image conversion: absent for mixed extensions", formats.isDisjoint(with: ids(menu(mixed))))
        check("new file: every catalog template", Set(NewFileCatalog.templates.map(\.id)).isSubset(of: ids(menu(folderBackground))))

        state.visibilityRules = [VisibilityRule(actionID: BuiltInActionCatalog.copyFullPath.id, mode: .exclude)]
        check("visibility: hidden built-in absent", !ids(menu(txt)).contains("copy-full-path"))
        check("visibility: unrelated built-in retained", ids(menu(txt)).contains("copy-posix-path"))
        state.visibilityRules = []
        check("visibility: clearing rule restores action immediately", ids(menu(txt)).contains("copy-full-path"))
        state.visibilityRules = [VisibilityRule(actionID: BuiltInActionCatalog.copyFullPath.id, mode: .include, requiredFileExtensions: ["txt"])]
        check("visibility: matching include is visible", ids(menu(txt)).contains("copy-full-path"))
        check("visibility: nonmatching include is hidden", !ids(menu(png)).contains("copy-full-path"))
        state.visibilityRules.append(VisibilityRule(actionID: BuiltInActionCatalog.copyFullPath.id, mode: .exclude))
        check("visibility: exclude takes precedence over include", !ids(menu(txt)).contains("copy-full-path"))
        state.visibilityRules = [VisibilityRule(actionID: BuiltInActionCatalog.compressItems.id, mode: .exclude, minimumSelectionCount: 2)]
        check("visibility: conditional exclude retains single selection", ids(menu(txt)).contains("compress-items"))
        check("visibility: conditional exclude hides multi selection", !ids(menu(mixed)).contains("compress-items"))
        state.visibilityRules = [VisibilityRule(actionID: BuiltInActionCatalog.convertImage.id, mode: .exclude)]
        check("visibility: hiding conversion removes dynamic formats", formats.isDisjoint(with: ids(menu(png))))
        state.visibilityRules = NewFileCatalog.all.map { VisibilityRule(actionID: $0.id, mode: .exclude) }
        check("visibility: all new-file templates hidden", Set(NewFileCatalog.templates.map(\.id)).isDisjoint(with: ids(menu(folderBackground))))
        check("visibility: all-hidden new-file submenu removed", !menu(folderBackground).items.contains { $0.submenu?.title == L("新建", "New") })
        state.visibilityRules = [VisibilityRule(mode: .exclude)]
        check("visibility: global exclude removes catalog actions", ids(menu(txt)) == ["utility:reveal-in-finder", "utility:open-preferences"])
        check("visibility: utilities remain reachable under global exclusion", ids(menu(toolbar)) == ["utility:open-preferences", "utility:refresh-targets"])

        let enabled = CustomAction(name: "Enabled text action", scriptContent: "echo fixture", fileExtensionFilter: ["txt"])
        let disabled = CustomAction(name: "Disabled action", scriptContent: "echo fixture", isEnabled: false)
        let multiple = CustomAction(name: "Multiple selection action", scriptContent: "echo fixture", minimumSelectionCount: 2)
        state = PersistenceState(customActions: [enabled, disabled, multiple])
        let enabledID = enabled.toActionDefinition().id.rawValue
        let disabledID = disabled.toActionDefinition().id.rawValue
        let multipleID = multiple.toActionDefinition().id.rawValue
        check("custom: enabled matching action visible", ids(menu(txt)).contains(enabledID))
        check("custom: disabled action hidden", !ids(menu(txt)).contains(disabledID))
        check("custom: file extension filter applied", !ids(menu(png)).contains(enabledID))
        check("custom: minimum selection excludes single", !ids(menu(txt)).contains(multipleID))
        check("custom: minimum selection includes multiple", ids(menu(mixed)).contains(multipleID))
        state.visibilityRules = [VisibilityRule(actionID: enabled.toActionDefinition().id, mode: .exclude)]
        check("custom: visibility rule applied", !ids(menu(txt)).contains(enabledID))
        state.customActions[1].isEnabled = true
        check("custom: newly enabled action loads on next menu", ids(menu(txt)).contains(disabledID))

        state = PersistenceState()
        let cloudAI: Set<String> = [AIActionCatalog.smartRename.rawValue, AIActionCatalog.autoTag.rawValue]
        let localAI: Set<String> = [AIActionCatalog.ocrExtract.rawValue, AIActionCatalog.removeBackground.rawValue]
        check("AI: cloud actions shown when enabled", cloudAI.isSubset(of: ids(menu(png))))
        check("AI: local actions shown when enabled", localAI.isSubset(of: ids(menu(png))))
        state.aiConfig.isEnabled = false
        check("AI: cloud actions hidden when disabled", cloudAI.isDisjoint(with: ids(menu(png))))
        check("AI: local actions retained when cloud disabled", localAI.isSubset(of: ids(menu(png))))
        state.visibilityRules = AIActionCatalog.all.map { VisibilityRule(actionID: $0.id, mode: .exclude) }
        check("AI: rules can hide local actions", localAI.isDisjoint(with: ids(menu(png))))
        check("AI: all-hidden AI submenu removed", !menu(png).items.contains { $0.submenu?.title == "AI" })
        let readsBefore = loadCount
        _ = menu(txt)
        _ = menu(txt)
        check("state: provider reloaded for new menus", loadCount == readsBefore + 2, "\(loadCount) state reads")

        enum FixtureError: Error { case unavailable }
        let unavailableComposer = SuperRClickFinderMenuComposer(stateProvider: { throw FixtureError.unavailable })
        let fallback = unavailableComposer.makeMenu(for: txt, target: target)
        check("state read failure: preferences remain reachable", ids(fallback).contains("utility:open-preferences"))
        check("state read failure: built-in actions available", ids(fallback).contains("copy-full-path"))

        let failures = checks.filter { $0.status == "FAIL" }.count
        let report = "# Offline Finder menu checks\n\n| Check | Status | Detail |\n|---|---|---|\n"
            + checks.map { "| \($0.name) | \($0.status) | \($0.detail) |" }.joined(separator: "\n")
            + "\n\n\(checks.count - failures)/\(checks.count) passed.\n\nReal Finder integration: **BLOCKED** — this harness does not install, register, enable, launch, or click the Finder extension. It does not execute any menu actions. macOS 15 and Intel runtime: **NOT RUN**.\n"
        try report.write(to: fixtureRoot.appendingPathComponent("matrix.md"), atomically: true, encoding: .utf8)
        try JSONEncoder().encode(checks).write(to: fixtureRoot.appendingPathComponent("results.json"))
        print("RESULT: \(checks.count - failures)/\(checks.count) PASS; \(failures) FAIL")
        exit(failures == 0 ? 0 : 1)
    }
}
