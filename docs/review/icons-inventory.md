# Icon source and consumption inventory

Audit scope: App, Shared, Extensions, asset catalogs, project configuration, and related branding/packaging resources. There is no top-level `Resources` directory in this repository. Line-accurate current static-key references are in [icons-source-coverage.json](icons-source-coverage.json); the table below records the consumer responsibilities found before replacement and their migration targets. Lines can move as the ongoing functional changes are merged.

## Shared vocabulary sources

| File | Source/call type | Scope |
|---|---|---|
| `Shared/Models/ActionDefinition.swift` | `systemImageName: String?` persisted semantic field | Built-in action definitions and fallbacks |
| `Shared/Models/CustomAction.swift` | `systemImageName`, default `bolt`; `CustomActionType.iconName` switch | User choices plus Shell/AppleScript/open-application types |
| `Shared/Actions/BuiltInActionCatalog.swift` | Eight `systemImageName` literals | Copy variants, Terminal, ZIP, rename, image, selected text |
| `Shared/Actions/AIActionCatalog.swift` | Four `systemImageName` literals | AI rename, tags, OCR, cutout |
| `Shared/Actions/NewFileCatalog.swift` | 18 template tuples containing icon keys | Document/Office/code/file types; shared keys are intentional |
| `Shared/AI/LLMProvider.swift` | `iconName` presets, formerly `logoDomain` | Nine provider presets; remote logos were a separate image source |
| `Shared/Design/RClickIcon.swift` | Original Core Graphics paths, alias dictionary, PDF-backed templates | Single current rendering source; 72 glyphs and 159 keys |

## App consumers

| File | Explicit app-controlled icon uses |
|---|---|
| `App/SuperRClickApp.swift` | Menu bar symbol, formerly scaled application icon; now `brand` |
| `App/SuperRClickRootView.swift` | Six sidebar destinations, add action, Finder status, application brand, explicit sidebar toggle |
| `App/Bootstrap/AppCoordinator.swift` | Four banner status key values: information, success, warning, error |
| `App/MenuBar/MenuBarRootView.swift` | Application brand, five quick tools; native Label icon helper |
| `App/Features/Actions/ActionComponents.swift` | Shared `ActionSymbol`, status banner glyph, dismiss glyph |
| `App/Features/Actions/ActionLibraryView.swift` | Refresh/add toolbar, catalog/custom glyphs, pinned/unpinned state, overflow, empty/search result illustration |
| `App/Features/Actions/CreateActionView.swift` | Draft glyph, icon picker choices, execution type glyphs, validation error |
| `App/Features/Actions/PinnedActionsView.swift` | Rename shortcut, dynamic catalog icon, empty pin, run, unpin |
| `App/Features/Actions/RecentActivityView.swift` | Clear, empty history, dynamic success/blocked/failure/missing-handler outcome glyphs |
| `App/Features/BatchRename/BatchRenamePanelView.swift` | Ready banner, per-preview success/unchanged/conflict, conflict warning |
| `App/Features/Tools/ToolsView.swift` | Four tool-card glyphs, hint, navigation arrow |
| `App/Features/Progress/TaskProgressWindow.swift` | In-progress document, success/error result |
| `App/Features/AI/AIResultWindow.swift` | Close and copy/copied states |
| `App/Features/Settings/AISettingsView.swift` | Provider glyphs, save/saved, connection success/error, persistence error; previously remote Clearbit `AsyncImage` with SF fallback |
| `App/Features/Settings/GeneralSettingsView.swift` | Application brand, language, Dock, update, setup |
| `App/Features/Settings/SettingsView.swift` | Settings destinations, About brand/fallback |
| `App/Features/Settings/ActionVisibilityView.swift` | Dynamic action-definition glyphs |
| `App/Features/Settings/ExtensionStatusBanner.swift` | Extension warning, dismiss, system settings shortcut |
| `App/Features/Settings/WorkspaceSettingsView.swift` | Global coverage, Desktop/Documents/Downloads, information, profiles/workspace |
| `App/Features/Settings/WorkspaceProfileView.swift` | Root-folder choices and built-in/custom folder rows |
| `App/Features/Setup/SetupCenterView.swift` | App brand, folder, completion, recommended actions, security, accessibility, keyboard, permission success |
| `App/Features/DesktopBridge/DesktopBridgeMenuBuilder.swift` | AppKit menu images for new-file group, settings, and every dynamic action |

All controlled `Image(systemName:)`, `Label(systemImage:)`, and `NSImage(systemSymbolName:)` consumers above migrate to the shared original renderer. The final consumer migration and live UI screenshots are owned by the main task. Core Graphics paths have no system-symbol fallback.

## Finder and resources

| File/directory | Source/call type and disposition |
|---|---|
| `Extensions/FinderSync/SuperRClickFinderSync.swift` | Finder toolbar image formerly `gearshape.fill`; original image via registry |
| `Extensions/FinderSync/SuperRClickFinderMenuComposer.swift` | Group images, dynamic action and conversion images; former `NSImage(systemSymbolName:)` tint helper; former `🤖` text prefix removed by the consumer migration |
| `Extensions/Services`, `Extensions/AppIntents` | No app-authored image drawing calls found |
| `App/Assets.xcassets/AppIcon.appiconset` | Ten macOS AppIcon PNG slots; regenerated from original Swift paths |
| `Extensions/FinderSync/Assets.xcassets/AppIcon.appiconset` | Same ten original slots for the Finder extension |
| Former `App/Assets.xcassets/pro_*.imageset` | Five unused provider image sets removed by the main task: custom/OpenAI/Ollama PNG; Moonshot/Zhipu `.ico` files were actually HTML documents |
| `project.yml` | App and extension resource catalogs; both `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` |
| `SuperRClick.xcodeproj/project.pbxproj` | Generated AppIcon target settings and Shared source membership |
| `assets/icon.png` | README brand image, synchronized with the new master |
| `Support/Assets/SuperRClick.iconset`, `SuperRClick.icns` | Packaging assets synchronized with the new source |
| `Support/Assets/SuperRClick-icon-master.png`, `icon-source/master-logo.png` | Generated previews, synchronized; no longer independent input sources |
| `Support/Assets/generate_app_icons.sh` | Tracked entry point now delegates to the authored Swift renderer |
| `Support/Build/generate_app_icons.py` | Existing local ignored compatibility script also updated; not part of the delivered source |
| `docs/release/SuperRClick-logo.svg` | New editable SVG geometry matching the original brand |
| `scripts/render_original_icons.swift` | Reproducible local Core Graphics/ImageIO pipeline; no external image inputs |

`Shared/AI/LocalVisionService.swift` also constructs `NSImage`/`CIImage`, but those objects are user image contents being processed, not interface icons.

## Native control boundary

Keep system-managed window traffic lights, picker and checkbox internals, search field magnifier/clear affordances, standard alert/file-dialog chrome and external file/application icons, and progress indicators native. These are different from explicit app-authored symbol requests, which are replaced. The sidebar toolbar button is app-controlled and therefore uses the original `sidebar` drawing.
