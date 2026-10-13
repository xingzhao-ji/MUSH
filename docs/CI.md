# Continuous integration

The `Headless source checks` workflow runs on pushes to `main` and pull requests using a standard Ubuntu runner, Python 3.12 and the official Godot 4.7.2 Linux archive. Actions are pinned to commits and the engine archive is SHA-256 verified. The token has only `contents: read`; no credentials, deploys or release uploads are used.

## Gates

- Eight standard-library tests for honest verification receipts, failed native checks, preservation, compaction and renderer-progress evidence.
- The existing clean-import suite, including its source-preservation audit and unchanged 10 GiB disk reserve.
- Existing headless flower-build, forest-build and paving shape-build suites. Their assertions and preservation checks are unchanged; generated candidates stay beneath ignored reports.
- The existing live-scene smoke runner with `--smoke --exercise-effects`: at least 12 checks for loaded snapshot, player and collision bindings, live material aliases, initialized motion, startup readiness, explicit firefly shader, advancing motion, pause behavior, and completed night/rain transitions.
- An unchanged tracked source tree after the checks.

The smoke report and process exit must both pass, and engine error lines fail the job. Saves are isolated beneath the temporary runner directory. Generated imports and reports remain uncommitted.

## Deliberately separate evidence

This is a headless startup gate, not a full-game acceptance badge. It does not run the 295-assertion rendered acceptance suite, image/capture review, frame-time benchmarks, native export, manual play, live audio or physical-device checks. Those retain their existing commands and requirements in README.md and docs/VERIFICATION.md.

The known upper-soil/near-cut paving contact-coverage failure (164/165 in the recorded traversal result) remains a failure. This workflow neither runs that rendered traversal gate nor weakens, skips within, or marks its assertions successful. A passing headless job does not resolve that issue.

No asset, gameplay behavior, scene, save format or existing verification assertion was changed to add CI.
