# Icon Source

This folder now contains the reusable master source for the app icon pipeline.

Primary file:
- `master-logo.png`

Current state:
- The asset catalogs are wired.
- `master-logo.png` is generated from the local icon builder and can also be replaced by a custom higher-fidelity source later.
- Running `bash Support/Assets/generate_app_icons.sh` with no arguments regenerates the procedural icon and refreshes both app icon sets.
- Running `bash Support/Assets/generate_app_icons.sh /path/to/custom-master.png` rasterizes a custom master image into both icon sets.
