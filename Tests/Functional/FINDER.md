# Finder validation

## Offline menu checks

Run after building the current `Shared.framework`:

```bash
bash Tests/Functional/run_finder_menu_checks.sh build/review/Build/Products/Debug
```

This compiles the production Finder context and menu composer with a selector-only stub. It injects in-memory action preferences and uses a fresh `/tmp` fixture directory. It never constructs `FIFinderSync`, executes a menu action, reads/writes the persisted action configuration, installs/registers/enables the extension, or grants system permissions. `SharedLocale` may read existing language defaults; the harness does not change them. Results are copied to `output/review/functional-finder-menu/matrix.md` and `results.json`.

Checks cover selection, multiple selection, directories, both background surfaces, sidebar, toolbar, empty selection, visibility includes/excludes, custom enabled state/filters, cloud AI switches, local AI, every new-file template, dynamic image formats, menu targets, and original template icons. On macOS 27 the image visibility preference is also checked. The executable targets macOS 15, but running it on macOS 27 does not verify macOS 15 or Intel runtime behavior.

## Real Finder integration: pending consent

The steps below are a future validation procedure; they have **not** been executed as part of the offline checks. The unsigned Release build and the entitlement-stripped Debug preview are not installed test applications. Use a fresh Release build, preserving both app and extension entitlements.

Minimum consent covers staging and local signing, installing this app at `~/Applications/SuperRClick.app`, launching it with real configuration storage, registering the embedded Finder extension if needed, enabling it in System Settings, and creating/reading/modifying disposable fixtures under this repository's `output/functional-finder-fixtures`. Clipboard actions are excluded from this minimum scope: verify only that copy-path menu items are present or hidden as configured; do not execute them or read the clipboard. An existing installation must be handled separately; the commands below stop before overwriting it.

Finder enablement is separate from Accessibility and Input Monitoring. Do not grant either optional DesktopBridge permission for this Finder test. On initial launch, `DesktopBridgeManager` only calls `AXIsProcessTrustedWithOptions(nil)` and `CGPreflightListenEventAccess()`, which check existing grants; explicit request methods belong to the setup buttons. **If both permissions were already granted**, launch/activation starts the existing DesktopBridge event tap. Normal app bootstrap also loads/migrates/saves its configuration and consumes queued external commands. Launching or registering an extension that was previously enabled can allow macOS to load it immediately; registration is not guaranteed to be inert.

### 1. Stage a fresh app and sign the staged copy

Run only after the consent above. The current Xcode project must already contain the latest source files (generate it with the repository's normal XcodeGen workflow if necessary).

```bash
finder_repo='/Users/haoqiqin/VibeCoding/Super RClick'
finder_stage="$(mktemp -d "$finder_repo/output/finder-validation-stage-XXXXXX")"
xcodebuild -project "$finder_repo/SuperRClick.xcodeproj" -scheme SuperRClick \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$finder_stage/DerivedData" CODE_SIGNING_ALLOWED=NO build
ditto "$finder_stage/DerivedData/Build/Products/Release/SuperRClick.app" \
  "$finder_stage/SuperRClick.app"
finder_app="$finder_stage/SuperRClick.app"
codesign --force --sign - --timestamp=none "$finder_app/Contents/Frameworks/Shared.framework"
codesign --force --sign - --timestamp=none \
  --entitlements "$finder_repo/Config/SuperRClickFinderSync.entitlements" \
  "$finder_app/Contents/PlugIns/SuperRClickFinderSync.appex"
codesign --force --sign - --timestamp=none \
  --entitlements "$finder_repo/Config/SuperRClick.entitlements" "$finder_app"
codesign --verify --strict --verbose=2 "$finder_app/Contents/PlugIns/SuperRClickFinderSync.appex"
codesign --verify --strict --verbose=2 "$finder_app"
bash "$finder_repo/scripts/verify_compatibility.sh" "$finder_app" 15.0
```

This matches the repository's local ad hoc signing approach. Signature verification alone does not prove macOS will load the sandboxed extension. If macOS rejects it, retain the logs and stop; do not strip entitlements, create credentials, or change system security settings. Using an existing authorized signing identity would be a separate decision.

### 2. Install without overwriting, then enable through the native interface

```bash
finder_installed="$HOME/Applications/SuperRClick.app"
test ! -e "$finder_installed" && test ! -L "$finder_installed" || exit 1
mkdir -p "$HOME/Applications"
ditto "$finder_app" "$finder_installed"
open "$finder_installed"
pluginkit -m -A -D -v -i com.haoqiqin.SuperRClick.FinderSync
```

Use **Setup → Open Finder Extension Settings** in Super RClick. This calls Apple's native `FIFinderSyncController.showExtensionManagementInterface()`. Enable only **Super RClick Finder Sync**. The manual path on macOS 15–27 is **System Settings → General → Login Items & Extensions → Finder**. Return to the app and verify the native status refreshes to enabled.

If the installed extension is still absent from the read-only PlugInKit listing, the following explicitly registers that installed extension; run only within the consent above, then repeat the listing and native enablement:

```bash
pluginkit -a "$finder_installed/Contents/PlugIns/SuperRClickFinderSync.appex"
pluginkit -m -A -D -v -i com.haoqiqin.SuperRClick.FinderSync
```

Do not automatically restart Finder or toggle unrelated extensions. A necessary Finder restart requires separate consent because it interrupts Finder windows and ongoing operations.

### 3. Use a fresh test folder under the monitored home directory

```bash
finder_fixture_root="$finder_repo/output/functional-finder-fixtures"
mkdir -p "$finder_fixture_root"
finder_fixture="$(mktemp -d "$finder_fixture_root/run-XXXXXX")"
mkdir "$finder_fixture/selected folder"
printf 'Known disposable fixture\n' > "$finder_fixture/notes.txt"
printf 'Nested disposable fixture\n' > "$finder_fixture/selected folder/nested.txt"
open "$finder_fixture"
```

The extension currently monitors the real user's home directory. This repository is inside that home directory; `/tmp` is unsuitable for the real integration test. Use only generated images/documents and newly created fixture paths.

Manual checks: right-click a file, a directory, mixed selection and folder background; check all new-file templates, conversion formats, copy-path menu visibility, and ZIP contents. Repeat creation/compression to verify independent outputs. Toggle a built-in visibility rule and custom enabled state, then reopen the menu; also keep an old custom menu open while disabling its action and confirm execution is rejected. Exercise cloud AI disabled/enabled menu behavior without submitting a paid/network AI action. Capture the displayed menus and record actual outputs, failures and permission prompts. Offline menu results do not count as these integration checks. A user may separately test copying paths manually; doing so replaces the clipboard contents. Automated validation must neither execute those actions nor read the clipboard.

macOS 15.6.1 launch/Finder checks and Intel execution require separate environments. They remain **NOT RUN** on this Apple Silicon macOS 27 host.

References: [Apple native Finder extension status](https://developer.apple.com/documentation/findersync/fifindersynccontroller/isextensionenabled), [native management interface](https://developer.apple.com/documentation/findersync/fifindersynccontroller/showextensionmanagementinterface()), [Login Items & Extensions](https://support.apple.com/guide/mac-help/change-login-items-extensions-settings-mtusr003/mac), [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes).
