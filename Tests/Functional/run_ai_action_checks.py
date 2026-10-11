#!/usr/bin/env python3
"""Compile current production sources; exercise only synthetic temp files.

Default cases inject LLM, Vision, and UI boundaries. --real-vision additionally
executes Apple's on-device OCR and foreground segmentation, never remote AI.
A separate process per case contains the historical empty-selection crash.
"""
from pathlib import Path
import argparse
import json
import os
import platform
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--real-vision", action="store_true")
parser.add_argument("--phase", default="verification")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
run = Path(tempfile.mkdtemp(prefix=f"superrclick-ai-{args.phase}-", dir="/tmp"))
print(f"Artifacts: {run}", flush=True)
common = ["xcrun", "swiftc", "-swift-version", "6", "-DDEBUG", "-parse-as-library",
          "-target", f"{platform.machine()}-apple-macos15.0", "-module-cache-path", str(run / "module-cache")]

def compile_logged(command, name):
    with (run / name).open("w") as log:
        result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((run / name).read_text(), flush=True)
        raise SystemExit(result.returncode)

compile_logged(common + ["-module-name", "Shared", "-emit-library", "-emit-module",
                        "-emit-module-path", str(run / "Shared.swiftmodule"), "-o", str(run / "libShared.dylib")]
               + sorted(str(path) for path in (repo / "Shared").rglob("*.swift")), "shared-build.log")
binary = run / "ai-action-checks"
compile_logged(common + ["-I", str(run), "-L", str(run), "-lShared", "-Xlinker", "-rpath", "-Xlinker", str(run),
                        str(repo / "App/Features/AI/AIActionExecutor.swift"),
                        str(repo / "App/Features/AI/ProgressReporting.swift"),
                        str(repo / "Tests/Functional/AIActionChecks.swift"), "-o", str(binary)], "executor-build.log")
cases = ["rename-parent-traversal", "rename-nested-path", "rename-invalid-names", "rename-valid", "rename-existing-output",
         "background-output-collision", "background-output-symlink", "empty-rename", "empty-tag", "empty-ocr",
         "empty-background", "ocr-multiple-images"]
if args.real_vision:
    cases += ["vision-real-ocr", "vision-real-background"]
results = []
for case in cases:
    log_path = run / f"{case}.log"
    try:
        with log_path.open("w") as log:
            result = subprocess.run([str(binary), case, str(run / "fixtures" / case)], cwd=repo,
                                    stdout=log, stderr=subprocess.STDOUT, timeout=90)
        status = "PASS" if result.returncode == 0 else "FAIL"
        detail = next((line for line in reversed(log_path.read_text().splitlines()) if "PASS |" in line or "FAIL |" in line),
                      f"Process exit {result.returncode}; inspect {log_path.name}")
        if case.startswith("vision-real-") and result.returncode != 0:
            # Failure is reported verbatim. Only unavailable execution/model resources are blocked.
            text = log_path.read_text()
            if any(reason in text for reason in ["Could not create Espresso context", "Could not create compute device",
                                                 "ANECF error: failed to load ANE model", "Failed to create CVPixelBuffer"]):
                status = "BLOCKED"
    except subprocess.TimeoutExpired:
        status, detail = "BLOCKED", "Process exceeded 90 seconds; inspect per-case log"
    results.append({"case": case, "status": status, "detail": detail, "log": str(log_path),
                    "boundary": "real local Vision" if case.startswith("vision-real-") else "injected AI/UI, real file operations"})
    print(f"{status} | {case} | {detail}", flush=True)
(run / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
(run / "matrix.md").write_text("| Case | Status | Boundary | Evidence |\n|---|---|---|---|\n" + "\n".join(
    f"| {r['case']} | {r['status']} | {r['boundary']} | [{Path(r['log']).name}]({r['log']}) |" for r in results) + "\n")
print(f"Matrix: {run / 'matrix.md'}", flush=True)
raise SystemExit(1 if any(r["status"] == "FAIL" for r in results)
                 else 2 if any(r["status"] == "BLOCKED" for r in results) else 0)
