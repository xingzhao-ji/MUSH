# Clean repository implementation plan

**Goal:** Preserve the current development game in a portable private Git repository after measured cleanup and bounded optimization.

**Architecture:** Retain the active Godot scene, native baked geometry and existing runtime inheritance. Exclude historical builds, generated imports and report archives. Make only measured, behavior-preserving improvements.

**Stack:** Godot 4.7.2, GDScript, Forward+/Metal, Python standard library, Git/GitHub CLI.

- [x] Verify old app archives before removing extracted duplicates; losslessly compact reports and read back every payload.
- [x] Curate current243 source into a separate repository; restore normal windows, portable exports and existing portable captures.
- [ ] Inspect hot paths and implement only a narrow justified optimization, with regression tests.
- [ ] Import cleanly, run original gameplay assertions, native visual captures and a sustained Mac benchmark.
- [ ] Record storage/complexity/performance limits, licenses, provenance and rollback; scan the Git payload.
- [ ] Commit and push a private repository; verify remote commit and clean checkout.

Review focus: private save isolation, all runtime inheritance dependencies retained, pinned resource proofs unchanged, no reference pixels or credentials uploaded, native timing separated from phone/manual acceptance.

Practices: pinned obra/superpowers planning, systematic debugging, test-first changes and fresh verification. No additional framework or global hook.
