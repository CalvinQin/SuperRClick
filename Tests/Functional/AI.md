# AI functional checks

Run from the repository root with the installed macOS developer tools:

```sh
python3 Tests/Functional/run_ai_action_checks.py
python3 Tests/Functional/run_ai_action_checks.py --real-vision
bash Tests/Functional/run_ai_llm_checks.sh
```

Each run compiles current production sources with Swift 6 and creates its own `/tmp/superrclick-ai-*` directory. The printed directory retains compiler logs, per-case execution logs, JSON results, a Markdown matrix, and synthetic fixtures. No installed application is launched; no user preferences, clipboard, Keychain, or remote AI service are accessed.

The action harness injects only LLM/Vision calls, result presentation, and Finder reveal. The actual production executor performs the tested file moves, exclusive PNG writes, validation, empty-selection handling, and aggregation. Its 12 deterministic cases cover unsafe model names, normal and conflicting renames, existing outputs and dangling symlinks, repeated background output creation, all four empty-selection cases, and multiple-image OCR aggregation.

`--real-vision` adds two separate on-device checks. Both create their input PNGs using Core Graphics/Core Text. OCR must recognize both known strings through the real executor and real Vision implementation. Background removal must return a decodable 1200 × 700 PNG containing transparent background and opaque foreground. The synthetic apple fixture is deliberately simple; this verifies the pipeline, not segmentation quality across photographs. Real Vision checks require access to host compute/model resources. A restrictive execution sandbox can produce `Failed to create CVPixelBuffer` or an ANE model load error. Such results are recorded as `BLOCKED`, not passed. Exit statuses are 0 for all pass, 1 for failures, and 2 for blocked execution without failures.

The LLM harness uses injected synthetic key loading and fake HTTP transport. It verifies keyless Ollama, optional Bearer authentication, other providers' missing-key rejection, request/response formats, errors, and cancellation. Its results do not establish that a user's Ollama installation or any remote provider is reachable.

`AIVisionDiagnostics.swift` is a read-only diagnostic for a generated fixture. It records the detected foreground count, the Core Image blend extent, and whether infinite or source-bounded output can be rendered. It captured the background-removal regression: an unbounded clear image yielded infinite blend extent and `createCGImage` returned nil; bounding the clear layer and render rectangle to the source fixed the real Vision output.

The harness intentionally bypasses result-window presentation and Finder activation. Native window behavior and Finder extension delivery remain separate UI/integration checks.
