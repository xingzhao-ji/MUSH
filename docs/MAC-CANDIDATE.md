# Mac development candidate (mac064)

[Download the private mac064 prerelease](https://github.com/xingzhao-ji/MUSH/releases/tag/mac064).
This experimental 0.6.0 app includes the recent paving, flower/terrain and forest
changes, native trunk contacts, the closest-home rock support and the 5 mm native
collision margin. Accepted 0.5.7 and rollback 0.5.5 remain preserved separately.
Whole-game art and manual-play acceptance remain open.

Double-click `builds/mac-20261011-132118-71306/MUSH.app`, or run:

```sh
open builds/mac-20261011-132118-71306/MUSH.app
```

The adjacent `MUSH.zip` is 162,744,174 bytes (SHA256
`e2acdb066d5edc0ab285f0b55aefa0f04900478d743b353a4143c9ac815d10d4`).
GitHub's uploaded asset size and reported SHA-256 match. Source checkpoint:
`e934f3767eaf5cc8b2dfcd51010edbbefe2f3d72`. The universal binary has a verified
local ad-hoc signature; only arm64 was run. It is not notarized or store-signed.
Saves use a separate `MUSH-mac064` directory. Choose **Begin a new clearing**.
W/A/S/D walks, mouse looks, Space floats, G glows, E interacts, B decorates and
Escape opens pause/settings. **Save & quit** should enable **Continue** next time;
that ordinary UI roundtrip remains unverified for this candidate.

## Evidence and limits

- Source: 295 gameplay assertions / 15 scenarios, 137 environment assertions,
  all 58 paving movement routes, four gap routes and 30/60 FPS trunk/camera
  regressions pass. Foundation: 26 checks, 156 movement ticks and 12 paired stills.
  The separate upper-soil/near-cut contact-coverage gate remains failed.
- Exported app: 12 startup/effects checks, four decoded captures, strict signature
  and exact ZIP readback pass. Source, prior profiles and app payloads remain exact.
- Exported 120-second night/rain route: **p95 16.644 ms / p99 20.498 ms**, 9,946
  frames, two loops, zero stalls, 1920 x 1080/default VSync. The unchanged
  16.7/33.3 ms callback-time limits pass. Headroom is small; this is not GPU/display,
  sustained thermal or physical-mobile qualification, nor a causal speedup claim.
- Its offline clip fully decodes: 106 frames, 1280 x 720 at30 FPS (3.533 seconds),
  with AAC audio. This proves neither speaker playback nor real-time motion quality.
  A separate source trunk-route clip contains 643 frames/21.433 seconds.
- Ordinary startup reached CLEARING_READY, but the native UI tool returned
  `cgWindowNotFound` both for the app path and the observed running bundle ID.
  The owned session was terminated and reaped; its failed receipt remains.
  No ordinary save was created. Save/Continue was observed only on older mac061.
- Thick paving fronts/night readability, the plain side rock/rear join and other
  distant homes, water joins, the provisional character/interior and full reference
  fidelity remain unfinished. Manual controls, continuous motion, live listening
  and physical phones remain unverified. There is no ready IPA.

`DELIVERY.json` and adjacent receipts bind this artifact. Temporary export staging
was removed after verification. Prior builds/ZIPs, saves and references remain.
The previous mac063 app's p95 failure (18.049 ms) remains recorded in
[verification history](VERIFICATION.md); it is not replaced by this run's pass.
Builds, full captures and private profiles stay outside Git. The ZIP is a release asset.
