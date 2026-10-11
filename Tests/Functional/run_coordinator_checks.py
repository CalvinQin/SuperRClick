#!/usr/bin/env python3
"""Compile and run real coordinator/file behavior without presenting app windows.

Only window presentation boundaries are stubbed. Each run compiles current Shared
and App source, uses a fresh /tmp directory, and retains logs, fixture files, and
JSON results there for inspection. It never launches the installed application.
"""
from pathlib import Path
import hashlib
import json
import os
import platform
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
RUN = Path(tempfile.mkdtemp(prefix="superrclick-coordinator-", dir="/tmp"))
FUNCTIONAL = ROOT / "Tests" / "Functional"
print(f"Artifacts: {RUN}", flush=True)

# Other maintenance agents may still be editing the checkout. Compile an immutable
# Swift-source snapshot and retain its hashes instead of racing those edits.
SNAPSHOT = RUN / "sources"
manifest = {}
for source_root in (ROOT / "Shared", ROOT / "App", FUNCTIONAL):
    for source in sorted(source_root.rglob("*.swift")):
        relative = source.relative_to(ROOT)
        data = source.read_bytes()
        target = SNAPSHOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        manifest[relative.as_posix()] = hashlib.sha256(data).hexdigest()
(RUN / "source-sha256.json").write_text(json.dumps(manifest, indent=2, sort_keys=True))


def run_logged(command, filename, env=None):
    with (RUN / filename).open("w") as log:
        completed = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    lines = (RUN / filename).read_text().splitlines()
    if len(lines) > 80:
        lines = lines[:25] + [f"... full output: {RUN / filename} ..."] + lines[-25:]
    print("\n".join(lines), flush=True)
    if completed.returncode:
        raise SystemExit(completed.returncode)


common = ["xcrun", "swiftc", "-swift-version", "6", "-DDEBUG", "-parse-as-library",
          "-target", f"{platform.machine()}-apple-macos15.0",
          "-module-cache-path", str(RUN / "module-cache")]
shared_sources = sorted(str(path) for path in (SNAPSHOT / "Shared").rglob("*.swift"))
run_logged(common + ["-module-name", "Shared", "-emit-library", "-emit-module",
                    "-emit-module-path", str(RUN / "Shared.swiftmodule"),
                    "-o", str(RUN / "libShared.dylib")] + shared_sources, "shared-build.log")

# Compile the production progress value model verbatim, but suppress its window.
progress_source = (SNAPSHOT / "App/Features/Progress/TaskProgressWindow.swift").read_text()
model = progress_source.split("struct TaskProgressInfo", 1)[1].split("// MARK: - Progress Window Controller", 1)[0]
(RUN / "TaskProgressInfo.swift").write_text("import Foundation\nstruct TaskProgressInfo" + model)
excluded = {"App/SuperRClickApp.swift", "App/Features/Progress/TaskProgressWindow.swift",
            "App/Features/BatchRename/BatchRenamePanelView.swift"}
app_sources = sorted(str(path) for path in (SNAPSHOT / "App").rglob("*.swift")
                     if path.relative_to(SNAPSHOT).as_posix() not in excluded)
sources = app_sources + [str(RUN / "TaskProgressInfo.swift"),
                         str(SNAPSHOT / "Tests/Functional/CoordinatorWindowStubs.swift"),
                         str(SNAPSHOT / "Tests/Functional/CoordinatorBehaviorChecks.swift")]
binary = RUN / "coordinator-checks"
run_logged(common + ["-I", str(RUN), "-L", str(RUN), "-lShared",
                    "-Xlinker", "-rpath", "-Xlinker", str(RUN), "-o", str(binary)] + sources,
           "coordinator-build.log")

env = os.environ.copy()
env["SUPERRCLICK_TEST_STORAGE"] = str(RUN / "state")
env["SUPERRCLICK_FUNCTIONAL_REPORT"] = str(RUN / "results.json")
run_logged([str(binary)], "coordinator-run.log", env)
print(f"Results: {RUN / 'results.json'}", flush=True)
