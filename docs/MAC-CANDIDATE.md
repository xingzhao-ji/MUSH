# Mac development candidate (mac066)

[Download the private mac066 prerelease](https://github.com/xingzhao-ji/MUSH/releases/tag/mac066).
This experimental 0.6.0 app lifts three existing tree canopies to expose the third
home from the sampled ground and approach views. Roots, shared wind/materials,
overall geometry counts and coherent trunk collision are retained. Accepted 0.5.7
and rollback 0.5.5 remain preserved; whole-game art/play acceptance remains open.

Double-click `builds/mac-20261011-183516-13113/MUSH.app`, or run:

```sh
open builds/mac-20261011-183516-13113/MUSH.app
```

The adjacent ZIP is 164,451,093 bytes, SHA256
`a43cff3de58902b4c6004ba321541ab4d65ea844605fb1c4e3184f4f5f87e8d5`.
GitHub's seven uploaded asset sizes/digests and source tag match.
Source checkpoint: `b5c9f616ecfe6b1937f185a8dc1eb4dcdaea051e`.
The universal app has a verified local ad-hoc signature; only arm64 was run.
It is not notarized. Saves use the separate `MUSH-mac066` directory.

Choose **Begin a new clearing**. W/A/S/D walks, mouse looks, Space floats,
G glows, E interacts, B decorates and Escape opens pause/settings. Settings offer
Float toggle and reduced motion. **Save & quit** enables **Continue** next time;
the ordinary mac066 UI roundtrip is pending because native window access was
unavailable. The successful mac065 UI observations remain separate evidence.

## Evidence and limits

- Source: 295 gameplay assertions / 15 scenarios and 29 forest checks pass,
  including ten static window sightlines, 20 stem/collider matches, 36 camera
  poses and four contact routes / 19 checks. Twelve immediate before/after
  preview images and ten integrated stills are retained.
- Export: 12 startup checks, strict signature and exact ZIP comparison pass.
  The first capture phase timed out after one image; its failed receipt remains.
  A separate retry using the same app with a topmost test window passes all four
  fully decoded 960 × 960 screenshots. All four were visually reviewed.
- Exported 120-second night/rain benchmark: **p95 10.619 ms / p99 13.759 ms**,
  15,177 samples, two loops, zero stalls, 1920 × 1080/default VSync. The unchanged
  16.7/33.3 ms limits pass, with engine draw progress at every recorded interval.
  The matching source run passes 11.575/13.188 ms. Neither proves a causal speedup,
  GPU/display presentation or thermal performance; prior failures remain failed.
- A 106-frame, 1280 × 720, 30 FPS offline in-engine clip fully decodes (3.533 s).
  Continuous motion quality and speaker playback remain unverified.
- Paving contact coverage still fails separately. Thick paving fronts, dark night
  paving, landscape/water joins, regular foliage bands, the plain support rock,
  provisional character/interior and full reference fidelity remain unfinished.
  Comprehensive moving-camera visibility, sustained manual controls, live audio
  and physical mobile devices remain pending. There is no ready IPA.

`DELIVERY.json` links the immutable package and verification receipts. Source,
prior profiles, ordinary candidate save, app and ZIP preservation passed.
Temporary export staging and the verified clip's working AVI were removed.
The source repository excludes builds/private profiles; the ZIP, delivery receipt,
four screenshots and short clip are release assets. Retained older ZIPs allow
recovery of previously removed duplicate extracted apps.
