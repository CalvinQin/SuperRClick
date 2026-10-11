# Original Super RClick icon system

2026-10-11. The editable sources are `Shared/Design/RClickIcon.swift` and `scripts/render_original_icons.swift`. All icon paths were authored for this project; the renderer uses Core Graphics geometry, with no SF Symbols calls, emoji, provider logos, third-party icon packs, image downloads, or copied vector inputs.

## Vocabulary and drawing

- 72 semantic glyphs; 159 canonical and legacy keys.
- A 24-unit canvas with 1.8-unit round strokes and joins. The document fold and pointer cutout form the brand mark.
- Most glyphs use outlines. The action, run, pointer, and pinned shapes use filled emphasis. `pin` is outlined and `pin.fill` maps to a distinct filled `pinned` glyph, so pin state does not depend on color alone.
- UI images are PDF-backed `NSImage` templates. Foreground color, selection, disabled presentation, and increased contrast can use the enclosing native control's appearance.
- Existing `systemImageName` values remain data-compatible aliases. They never reach a system-symbol renderer. Unknown persisted user values fall back to the original `action` glyph.
- `sidebar` is an original split-pane drawing. Provider presets use semantic original glyphs rather than third-party company logos.

```swift
RClickIcon.image(named: "brand", size: 20) // MainActor, nonoptional NSImage template
Image(rclick: "sidebar")
RClickLabel("New Action", icon: "plus").labelStyle(.titleAndIcon)
```

The enclosing control provides the accessible name. The icon template itself has no redundant accessibility description. `RClickLabel` wraps native SwiftUI `Label`, preserving its styling and title semantics.

## Review images

- [All glyphs, light](icons-light.png): each cell shows 16, 20, 24, and 32 pixels from left to right.
- [All glyphs, dark](icons-dark.png): the same full vocabulary and sizes.
- [Template states](icons-states.png): representative glyphs at all four sizes in light, dark, selected, disabled/light, disabled/dark, high-contrast/light, and high-contrast/dark rows.
- [App icon master](icons-app-master.png): deep ink tile, teal folded document, warm pointer with a dark cutout border.
- [Registry manifest](icons-manifest.json): every canonical/legacy key and its actual glyph.
- [Source coverage](icons-source-coverage.json): static references found in current App/Shared/Extensions Swift source, including catalog tuples, dynamic status/provider key definitions, ternaries, fallbacks, and the custom editor choices. 96 unique keys, zero unsupported keys at audit time. This is source coverage, not a claim about arbitrary values in existing user data.

The final state sheet is 1244 pixels wide to retain clear right padding after the 32-pixel OCR example. Full-vocabulary sheets also retain the last cell and right margin. The source and generated sheets were visually checked without changing system appearance settings; runtime screenshots and end-to-end UI checks are recorded separately by the main task.

## Rebuild assets

Run from the repository:

```sh
bash Support/Assets/generate_app_icons.sh
```

The tracked shell wrapper compiles the two authored Swift files into a temporary directory; no packages are downloaded. It no longer imports arbitrary bitmap master files. Edit the vector source to change the design. The existing local `Support/Build/generate_app_icons.py` was also updated to delegate to this pipeline, but remains ignored by Git and is not a delivered entry point.

The Swift renderer refreshes:

1. `App/Assets.xcassets/AppIcon.appiconset` and `Extensions/FinderSync/Assets.xcassets/AppIcon.appiconset`: all ten macOS 1x/2x slots in each catalog, 16–1024 pixels.
2. `Support/Assets/SuperRClick.iconset` and `Support/Assets/SuperRClick.icns`, preserving all ten PNG-backed 1x/2x ICNS records and validating the result with the native ImageIO decoder.
3. `Support/Assets/SuperRClick-icon-master.png`, `Support/Assets/icon-source/master-logo.png`, and `assets/icon.png` used by the README.
4. `docs/release/SuperRClick-logo.svg`, using actual SVG geometry and gradients, not an embedded raster image.
5. The master preview, light/dark/state contact sheets, and registry manifest in this directory.

`project.yml` continues to use `AppIcon` for both targets; no dependency or framework changes are required beyond the existing AppKit/SwiftUI framework code.

## Validation and scope

The icon source and renderer compile with Swift 6 and the macOS 15 deployment target. The renderer completed successfully. Both catalogs' twenty PNG dimensions match their declared slots; matching PNGs across the two catalogs and packaging iconset are byte-identical. All three shipped master PNG copies match the review master. The release SVG contains editable vector paths without `<image>` elements. The native ICNS output is separately readable.

An initial attempt to use `/usr/bin/iconutil` rejected the otherwise readable PNG iconset. The native ImageIO ICNS writer then omitted the 1024-pixel record. The final renderer explicitly packages all ten PNG records into the ICNS container and requires the native decoder to recover the 1024-pixel master; no fallback to old assets occurs.

System-owned control chrome remains native: window traffic lights, search field magnifier/clear affordances, checkbox marks, picker arrows, standard file dialog content/icons, alert chrome, and progress spinners. They are not app-supplied illustration assets. The previously controllable default sidebar button was explicitly replaced by the original `sidebar` glyph. File contents processed by Vision and icons belonging to other applications are outside this icon vocabulary.
