# Super RClick Release Build And Install

## Build

Run the repeatable release packaging script:

```bash
./scripts/build_release_dmg.sh
```

What it does:
- Regenerates the Xcode project from `project.yml`
- Builds `SuperRClick.app` in `Release`
- Verifies the Finder Sync extension is embedded in the app bundle
- Stages the app and creates a compressed DMG in `output/release`

## Output

Expected output:
- `output/release/SuperRClick-<version>.dmg`
- `output/release/staging/INSTALL.txt`

## Install

1. Open the DMG.
2. Drag `SuperRClick.app` into `Applications`.
3. Launch the app once.
4. If the Finder extension is not active yet, enable it in `System Settings -> Extensions -> Finder Extensions`.
5. If Finder still shows no Super RClick menu, relaunch Finder once.

## Notes

- The current release script now applies local ad-hoc bundle signing to the staged app and embedded Finder Sync extension so `pluginkit` can register the extension on a development machine.
- The DMG already contains the app bundle with `SuperRClickFinderSync.appex` embedded.
- A polished icon source is kept separately so the icon worker can convert it into `AppIcon` assets without touching packaging logic.

## Troubleshooting

If the right-click menu does not appear:

1. Confirm Finder sees the extension:

```bash
pluginkit -m -A -D -p com.apple.FinderSync | grep SuperRClick
```

2. If nothing is listed, register the installed extension manually:

```bash
pluginkit -a "/Applications/SuperRClick.app/Contents/PlugIns/SuperRClickFinderSync.appex"
pluginkit -e use -p com.apple.FinderSync -i com.haoqiqin.SuperRClick.FinderSync
```

3. Restart Finder:

```bash
killall Finder
```
