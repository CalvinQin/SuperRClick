# Coordinator functional checks

Run from the repository root with the configured Xcode command-line toolchain:

```sh
python3 Tests/Functional/run_coordinator_checks.py
```

The runner builds the current `Shared` and `App` Swift sources as an isolated
executable from an immutable source snapshot. It does not launch or replace the installed app. A new
`/tmp/superrclick-coordinator-*` directory holds build logs, actual file fixtures,
isolated configuration, `coordinator-run.log`, machine-readable `results.json`,
and a `source-sha256.json` manifest identifying the compiled source snapshot.
The runner prints the artifact directory and exits nonzero on a build or check
failure. If a sandbox prevents Xcode's Observation macro compiler from starting,
run the same command with the host's approved local build permissions.

The harness exercises production `AppCoordinator`, `PlatformActionExecutor`,
action planning, persistence, and the production progress value model. Only main,
batch-rename, and progress window presentation is replaced with no-op boundaries.
The DEBUG storage override suppresses external-command monitoring, desktop
integration, and permission prompts. No clipboard actions, credential access,
remote AI, or network calls are invoked. All mutated files belong to the new
temporary directory.

Checks cover:

- Overlapping progress tasks, clear rejection feedback, late callbacks from old
  tasks, and admitting a new task after the previous operation completes.
- Real batch rename with spaces and Unicode, expected filenames, original content
  bytes, and exactly one successful history record.
- Consecutive Apply calls, cancellation during execution, both draft-edit APIs,
  another open request during execution, and a stale Apply after completion.
- Cancel before Apply, existing-target conflict without overwriting files, a
  source removed after preview, and cancellation after the failed operation.
- Isolated AI configuration values surviving unrelated pin persistence, explicit
  saving of the disabled state, a real atomic-write failure preserving shared
  configuration and the last saved data, and reload through a fresh coordinator.
- Desktop menus retaining local OCR and background removal when remote AI is off,
  restoring remote actions when it is on, and preserving eligible custom actions
  in both states. These checks inspect menus without executing AI.
- The real desktop menu builder and its action handler routing a saved custom
  action into an actual `/bin/sh` fixture. File-selection environment values,
  duplicate clicks, context changes, edited scripts, stderr and nonzero exits,
  disabled/deleted actions, selection validation, and temporary-file cleanup.
- Pure local AppleScript arithmetic, a 20 KB shell stdout stream, an absent
  process working directory, and a random nonexistent application identifier.
  These cases do not open another application or send Apple Events to one.

The local AI value test checks the coordinator's persistence boundary. It does
not claim to exercise SwiftUI's private `@State`, editor focus, accessibility
actions, real window close controls, Finder permissions, or Keychain. Those need
the UI/manual checks alongside this harness.
