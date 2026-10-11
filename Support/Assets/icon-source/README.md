# Original icon source

The editable source is the hand-authored Swift vector geometry in:

- `Shared/Design/RClickIcon.swift`: 24-unit UI glyphs, drawn with 1.8-unit rounded strokes.
- `scripts/render_original_icons.swift`: folded document and pointer app icon, raster exports, and contact sheets.

`master-logo.png` is a generated preview, not the input to the pipeline. No SF Symbols, emoji, provider logos, third-party icon packs, or downloaded image inputs are used by the pipeline.

Run `bash Support/Assets/generate_app_icons.sh` from the repository. This tracked entry point refreshes both AppIcon catalogs, the ICNS and iconset used by packaging, README artwork, the editable release SVG, and the review contact sheets.

Review `docs/review/icons-design.md`, `icons-light.png`, `icons-dark.png`, and `icons-states.png` for the vocabulary, sizes, and appearance checks.
