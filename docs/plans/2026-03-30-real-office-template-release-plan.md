# Real Office Template And Release Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn the recently added “New File” capability into a shippable feature set by locking down real Office templates, polishing asset/release work, and validating the Finder/Desktop flow end-to-end.

**Context:** The codebase has already moved beyond the earlier Finder/Desktop plan. `NewFileCatalog`, `NewFileData`, Finder-side creation, and app-side file creation are now in the tree. This plan reflects the current reality and the release-oriented work visible in the latest task board.

**Tech Stack:** SwiftUI, AppKit, FinderSync, Shared framework, App Group persistence, xcodebuild, shell tooling for packaging, optional image generation for app icons

---

## 1. Current Status Snapshot

### Already landed

- `Shared/Actions/NewFileCatalog.swift`
  - New File action definitions now exist, including `docx`, `xlsx`, and `pptx`.
- `Shared/Actions/NewFileData.swift`
  - Embedded Base64 template payloads are present in the repo.
- `App/Bootstrap/PlatformActionExecutor.swift`
  - Main app can create new files, including seeded Office files when Base64 data exists.
- `Extensions/FinderSync/SuperRClickFinderSync.swift`
  - Finder/Desktop can create new files directly from the contextual menu.
- Finder/Desktop batch rename plumbing
  - Shared external-command bridge exists and the app-side consumer is in place.

### Not yet closed out

- Real-world validation that the generated `docx/xlsx/pptx` files open cleanly in Office.
- App icon generation and asset catalog population.
- Workspace cleanup of temporary helper scripts and release leftovers.
- Release build, packaging, and install verification.

---

## 2. Workstream A: Lock Down Real Office Templates

**Goal:** Make sure `New Word / Excel / PowerPoint` reliably creates valid files, not just files with the correct extension.

**Files:**
- Verify: `Shared/Actions/NewFileCatalog.swift`
- Verify: `Shared/Actions/NewFileData.swift`
- Verify: `App/Bootstrap/PlatformActionExecutor.swift`
- Verify: `Extensions/FinderSync/SuperRClickFinderSync.swift`

**Steps:**
1. Validate that `docx`, `xlsx`, and `pptx` Base64 payloads decode into clean files.
2. Confirm both app-side creation and Finder-side creation prefer embedded Office payloads.
3. Manually open the generated files in real Office apps and check for corruption dialogs.
4. If any template is invalid, replace the payload rather than silently falling back to empty files.

**Definition of done:**
- Finder/Desktop “New Word”, “New Excel”, and “New PowerPoint” create files that open successfully in Office.

---

## 3. Workstream B: Unify New File Behavior

**Goal:** Keep the “New File” feature consistent between Finder Sync and the main app.

**Files:**
- Verify or modify: `App/Bootstrap/AppCoordinator.swift`
- Verify or modify: `App/Bootstrap/PlatformActionExecutor.swift`
- Verify or modify: `Extensions/FinderSync/SuperRClickFinderSync.swift`

**Steps:**
1. Make naming behavior consistent: `Untitled.ext`, then `Untitled 1.ext`, etc.
2. Make seeded content behavior consistent between the app and Finder extension.
3. Ensure new files are revealed/selected in Finder after creation.
4. Add focused tests where practical for the shared template-selection logic.

**Definition of done:**
- The same action title produces the same kind of file with the same naming rules no matter which entrypoint invokes it.

---

## 4. Workstream C: App Icon Pipeline

**Goal:** Replace placeholder branding with a proper icon set for both the app and Finder extension.

**Files:**
- Likely create or modify: `App/Assets.xcassets/**`
- Likely create or modify: `Extensions/FinderSync/Assets.xcassets/**`
- Optional scripts folder for resizing/export

**Steps:**
1. Create or generate a single master icon concept for macOS.
2. Export resized variants for `16, 32, 64, 128, 256, 512, 1024`.
3. Populate both the main app and Finder Sync asset catalogs.
4. Verify the icon appears correctly in Finder, Dock, and System Settings.

**Definition of done:**
- Both targets use a complete icon set and no placeholder icon remains.

---

## 5. Workstream D: Workspace Cleanup

**Goal:** Reduce confusion and release risk before packaging.

**Files:**
- Review repo for temporary helpers such as `temp_build/**`
- Review generated or stale build artifacts

**Steps:**
1. Decide which helper scripts are worth keeping and which should be deleted.
2. Remove stale DerivedData and leftover debug app artifacts from the local release flow.
3. Keep only repeatable generation scripts that the team will actually reuse.

**Definition of done:**
- The repo and local workspace no longer depend on one-off scratch scripts to reproduce release steps.

---

## 6. Workstream E: Release Build And Packaging

**Goal:** Produce a distributable build that can be installed and managed cleanly.

**Files:**
- Verify: `project.yml`
- Verify: `Config/*.plist`
- Create if needed: release notes or packaging helper script

**Steps:**
1. Run a clean `Release` build with `xcodebuild`.
2. Confirm the app and Finder extension are embedded correctly.
3. Package the result as `SuperRClick_Release.zip`.
4. Write down the exact install/enable steps for Finder Sync on a fresh machine.

**Definition of done:**
- A zipped Release artifact exists and the install steps are documented.

**Current state:**
- The repeatable DMG script now exists at `scripts/build_release_dmg.sh`.
- Release instructions now live at `docs/release/build-and-install.md`.
- The bundled Finder Sync extension is still embedded by the app target dependency, so the release packager only has to stage the built `.app` bundle.

---

## 7. Immediate Next Actions

1. Validate the real Office templates by creating and opening `docx/xlsx/pptx` from Finder/Desktop.
2. Finish the app icon pipeline so the product stops looking like a prototype.
3. Clean temporary helper scripts and prepare a repeatable Release packaging command.
