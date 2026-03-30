# Desktop Right-Click Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Super RClick support Finder item menus, Desktop background right-click, and user-configurable monitored folders with a shared action pipeline.

**Architecture:** Keep Finder Sync as the system-facing entrypoint, but let it translate Finder state into `Shared.ActionContext` and resolve actions from the shared catalog. Store monitored folders and workspace metadata in the app-group persistence layer so the app and the extension read the same configuration.

**Tech Stack:** SwiftUI, AppKit, FinderSync, Shared framework, App Group JSON persistence, xcodebuild tests

---

## Status Update (2026-03-30 PM)

This implementation plan is now mostly landed in code.

**Completed baseline:**
- Finder item menus, folder background menus, and Desktop background menus now share the same catalog-driven pipeline.
- Monitored folders are stored in the app-group state and configurable from the app settings UI.
- Batch rename now has a real native panel, a pure preview planner, and an app-group handoff path from Finder Sync into the main app.
- The main app and Finder extension both build successfully in `Debug`.

**Carry-forward items:**
- Do a manual Finder/Desktop validation pass for the external batch rename handoff on a real machine with the extension enabled.
- Keep tightening the “new file” and Office-template work that landed after this plan was written.
- Fold release prep, app icon generation, and packaging into a separate execution plan.

### Task 1: Model desktop/container context in shared plumbing

**Files:**
- Modify: `Shared/Models/ActionContext.swift`
- Modify: `Shared/Models/PersistenceState.swift`
- Modify: `Shared/Persistence/PersistenceController.swift`

**Steps:**
1. Add lightweight metadata support for Finder surface type and monitored folders.
2. Preserve backward-compatible persistence defaults.
3. Keep the model simple enough for the app shell and the Finder extension to share.

**Status:** Complete

### Task 2: Wire Finder Sync to the shared action catalog

**Files:**
- Modify: `Extensions/FinderSync/SuperRClickFinderContext.swift`
- Modify: `Extensions/FinderSync/SuperRClickFinderMenuComposer.swift`
- Modify: `Extensions/FinderSync/SuperRClickFinderSync.swift`

**Steps:**
1. Distinguish selection menus, container menus, and Desktop background menus.
2. Build menu sections from `BuiltInActionCatalog` instead of a hard-coded Finder-only list.
3. Route Finder actions through shared identifiers where possible, with honest placeholders only where UI handoff is still required.

**Status:** Complete for Desktop/Finder routing. Batch rename handoff is now implemented rather than placeholder-only.

### Task 3: Turn monitored folders into real settings

**Files:**
- Modify: `App/Bootstrap/AppCoordinator.swift`
- Modify: `App/Features/Settings/WorkspaceProfileView.swift`

**Steps:**
1. Load/save monitored folders and workspace cards from app-group state.
2. Expose Desktop as a first-class monitored workspace, not just a default assumption.
3. Make the settings screen clearly show what Finder/Desktop areas are covered.

**Status:** Complete

### Task 4: Land a first usable batch rename flow

**Files:**
- Create: `Shared/BatchRename/BatchRenamePlan.swift`
- Modify: `App/Bootstrap/PlatformActionExecutor.swift`
- Modify: `App/Bootstrap/AppCoordinator.swift`

**Steps:**
1. Add a pure rename-plan builder with previewable output.
2. Support a safe first mode such as prefix/suffix insertion with collision avoidance.
3. Surface a truthful blocked state when the caller is Finder Sync and a richer in-app handoff is needed.

**Status:** Complete for the first usable flow. The remaining work is manual validation and polish, not core plumbing.

### Task 5: Verify the new behavior

**Files:**
- Modify: `Tests/Unit/ActionContextTests.swift`
- Modify: `Tests/Unit/PersistenceControllerTests.swift`
- Create or modify focused tests for Finder/Desktop routing if needed

**Steps:**
1. Add unit coverage for Desktop context metadata and monitored-folder persistence.
2. Build the macOS app target.
3. Run the focused test suite and fix regressions before delivery.

**Status:** In progress. The app builds successfully; focused tests exist and continue to evolve as the product scope expands.
