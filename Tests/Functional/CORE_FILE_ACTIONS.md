# Real file operation checks

Run from the repository root after building `Shared.framework`:

```sh
bash Tests/Functional/run_core_file_checks.sh
```

Optional arguments select the framework directory and the report directory:

```sh
bash Tests/Functional/run_core_file_checks.sh \
  build/review/Build/Products/Debug \
  output/review/functional-core
```

Requirements: the matching Xcode Swift toolchain, an already-built `Shared.framework`, Python 3.11+, and macOS system `sips`/`zip`. This runner compiles the **current production** `PlatformActionExecutor.swift` directly with a small Swift harness, links Shared, and exercises the real executor/planner. It does not launch the app. The Finder reveal callback is the only substituted operation.

Each run creates a fresh `/tmp/superrclick-functional-core-*` directory and retains fixtures, generated files, the executable, compile/operation logs, JSON results, and a Markdown test matrix. The report directory receives copies plus `latest-fixtures.txt`. No test reads/writes the user clipboard, changes app preferences, runs remote AI, opens Terminal, changes permissions, or touches user documents.

The cases exercise:

- Every advertised new-file type, valid RTF decoding, naming collisions, repeated and concurrent creation, selection-parent behavior and missing destinations.
- DOCX/XLSX/PPTX ZIP CRC, mandatory parts, all XML, and internal relationship targets. This is structural validation; Microsoft Office itself is not launched.
- Real PNG → JPEG/PNG/TIFF/HEIC operations with ImageIO format/dimension decoding and source-byte preservation; repeated conversion, existing outputs, invalid input and mixed success/failure.
- Exclusive output publication: dangling symlinks survive both successful and failed actions, late-arriving files and existing directories are preserved, twelve concurrent publications retain every distinct payload, and failed conversion removes only its private staging files.
- Compression of files, directories, mixed selections, Unicode/spaces, leading hyphens, repeated actions and missing inputs. Independent Python checks verify complete archive membership and every extracted payload against the input bytes. Apple's system zip uses UTF-8 filename bytes without the UTF-8 flag; the checker explicitly decodes native names as UTF-8. Cross-platform filename compatibility is outside this run.
- Actual prefix/suffix/numbered file and directory renaming; unchanged names; existing/duplicate conflicts; path traversal prevention; rollback after late failure; rollback when another process creates a conflicting destination or original path during execution.

A case marked `PASS` actually ran and verified its expected success **or** expected error handling. A nonzero exit indicates one or more failed expectations. GUI buttons, native picker cancellation, Finder extension loading, clipboard, external apps, remote AI, signing, notarization, and Intel execution require separate checks.

If HEIC alone fails under an execution sandbox, preserve that log before diagnosing. On the current machine, system `sips` inside the sandbox reports `sysctlbyname ... kern.hv_vmm_present ... -1` and error 13, while the identical conversion outside it succeeds. Run the narrowly scoped temporary-file harness in an approved normal local execution environment to distinguish the environment restriction from an application defect. Do not remove a failed case or call it passed based only on compilation.
