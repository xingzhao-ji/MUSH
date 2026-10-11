# Mac development candidate (mac063)

This experimental 0.6.0 app contains the narrower lower and upper entrance
joints, the native paired-support stepping fix and restrained moonlit sky fill.
The accepted 0.5.7 app and 0.5.5 rollback remain retained separately. This is not
a whole-game acceptance or notarized release.

Current source additionally applies the existing Rock01 texture to the complete front paving batch through the existing triplanar shader. That material-only change is absent from this frozen mac063 app and ZIP; no new package is claimed. The current baked geometry is unchanged. The newer source passes 295 gameplay assertions and its 120-second callback-timing gate (p95 16.254 ms / p99 17.853 ms); this app's recorded results remain bound to its earlier source.

Double-click `builds/mac-20261011-081358-42723/MUSH.app`, or run:

```sh
open builds/mac-20261011-081358-42723/MUSH.app
```

The adjacent `MUSH.zip` is 162,620,746 bytes (SHA256
`2584703f15535c2d12260d9c8f7751610cb6c63e28af310acf5d50bfb83cd608`).
Its universal binary has a verified local ad-hoc signature; only arm64 was run.
The private GitHub `mac063` prerelease provides this same ZIP after upload.
Saves use a separate `MUSH-mac063` directory. Choose **Begin a new clearing**.
W/A/S/D walks, mouse looks, Space floats, G glows, E interacts, B decorates and
Escape opens pause/settings. **Save & quit** should enable **Continue** next time;
that ordinary UI roundtrip remains unverified for this candidate.

## Evidence and limits

- Source gameplay: 295 assertions / 15 scenarios pass. Final paving authoring:
  49 checks pass; all 58 movement routes and four additional gap routes pass.
  The upper-soil/near-cut contact-coverage check still fails.
- Exported app: 12 startup/effects checks, four decoded captures and strict
  signature/ZIP readback pass. Source, prior profiles and app payloads stay exact.
- Exported 120-second night/rain route: 9,678 frames, two loops, no stalls,
  1920 x 1080, default VSync; **p95 18.049 ms / p99 23.515 ms**.
  The unchanged 16.7 ms p95 limit fails. The source run's 16.302/18.321 ms result
  qualifies that source run only and predates the front-material fork. No causal
  speedup, GPU/display or mobile result.
- A 106-frame, 1280 x 720 offline30-FPS clip fully decodes (3.533 seconds).
  Its encoded audio track does not establish speaker playback or listening quality.
  Fixed-FPS capture does not establish real-time motion quality.
- Ordinary startup reaches `CLEARING_READY`, but the native UI tool repeatedly
  returned `cgWindowNotFound`. The bounded session was terminated and reaped;
  its failed receipt remains. No ordinary save was created. Save/Continue was
  observed only on older mac061, not this app.
- Thick stone fronts, dark night paving, provisional character/foliage/interior,
  water joins and overall reference fidelity remain unfinished. Manual controls,
  live audio, continuous real-time motion and physical phones remain unverified.

`DELIVERY.json` and adjacent receipts bind this artifact. Temporary export staging
was removed. Old mac061 is restorable from `builds/mac-20261011-042956-9202/MUSH.zip`;
its extracted duplicate was removed after full verification. mac062 remains
available separately with its own earlier failed p95 result. Builds, full captures
and private profiles remain outside Git; the prerelease ZIP is a release asset.
