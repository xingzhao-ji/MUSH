# Mac development candidate (mac065)

[Download the private mac065 prerelease](https://github.com/xingzhao-ji/MUSH/releases/tag/mac065).
This experimental 0.6.0 app includes the recent scenery, paving and forest changes,
plus complete placement of the two distant homes on the existing bank. Each home's
18 parts and actual window light move together. Accepted 0.5.7 and rollback 0.5.5
remain preserved separately. Whole-game art and manual-play acceptance remain open.

Double-click `builds/mac-20261011-144832-90462/MUSH.app`, or run:

```sh
open builds/mac-20261011-144832-90462/MUSH.app
```

The adjacent `MUSH.zip` is 164,449,080 bytes (SHA256
`1ccec56f30c9d1ff464a7322eb876c175c3668f497b75de340bbbbd7a8fde1b9`).
GitHub's uploaded asset size and reported SHA-256 match. Source checkpoint:
`1777353bef29cdf3b9d4b7250121a7ed36d12c8c`. The universal binary has a verified
local ad-hoc signature; only arm64 was run. It is not notarized or store-signed.
Saves use a separate `MUSH-mac065` directory. Choose **Begin a new clearing**.
W/A/S/D walks, mouse looks, Space floats, G glows, E interacts, B decorates and
Escape opens pause/settings. **Save & quit** should enable **Continue** next time;
that ordinary UI roundtrip was not exercised for this candidate.

## Evidence and limits

- Fresh source: 295 gameplay assertions / 15 scenarios, 137 environment checks,
  26 foundation checks / 156 movement ticks, and 14 placement checks / 16 paired
  images pass. All 58 unchanged paving movement routes retain their prior evidence;
  the separate upper-soil/near-cut contact-coverage gate remains failed.
- Exported app: 12 startup checks, four decoded screenshots, strict signature and
  exact ZIP readback pass. Source, prior profiles and app payloads remain exact.
- Exported 120-second night/rain route: **p95 17.524 ms / p99 22.847 ms**, 9,622
  frames, two loops, zero stalls, 1920 × 1080/default VSync. The unchanged 16.7 ms
  p95 gate fails; the 33.3 ms p99 gate passes. This build is uploaded as-is under
  user authorization. The failure remains recorded. The source route passes
  16.136 / 18.102 ms; that does not qualify the exported app or establish a speedup.
- Its offline clip fully decodes: 106 frames, 1280 × 720 at 30 FPS (3.533 seconds),
  with AAC audio. This proves neither speaker playback nor real-time motion quality.
- Ordinary mac065 UI was not exercised. Prior mac064 window access failed with
  `cgWindowNotFound`; no Save/Continue pass transfers from older mac061.
- Home3 remains foliage-obscured from the ground camera. Thick paving fronts,
  dark night paving, the plain side rock/rear join, water joins, the provisional
  character/interior and full reference fidelity remain unfinished. Manual controls,
  continuous motion, live listening, GPU/display/thermal measurements and physical
  phones remain unverified. There is no ready IPA.

`DELIVERY.json` and adjacent receipts bind this artifact. Temporary export staging
and the verified clip's intermediate AVI were removed after readback. Prior
builds/ZIPs, saves and references remain. Frozen mac064 retains its passing
16.644 / 20.498 ms result; this successor's failure does not rewrite it.
Builds, full captures and private profiles stay outside Git. The ZIP is a release asset.

Older development mac062/mac063 extracted apps were removed only after complete
comparison with their retained ZIPs and signature checks. Their archives and
verification evidence remain in the same build directories. Unzip the retained
`MUSH.zip` to recover either app; all seven payloads and file permissions per app
were checked. mac064/mac065, accepted057 and rollback055 stay extracted.
