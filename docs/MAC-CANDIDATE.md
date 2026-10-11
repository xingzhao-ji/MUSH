# Mac development candidate (mac061)

The later lower-joint geometry successor is currently tested in source. This mac061 app contains the earlier Rock01 surface checkpoint.

This experimental 0.6.0 build includes the weathered entrance-top material. It is
launchable on the tested Apple M4 Pro Mac; overall scenery and movement quality
remain unfinished. The retained 0.5.7 app and 0.5.5 rollback are untouched.

The local app is `builds/mac-20261011-042956-9202/MUSH.app`; double-click it, or run:

```sh
open builds/mac-20261011-042956-9202/MUSH.app
```

`MUSH.zip` beside it is the portable archive (162,431,790 bytes). The universal
binary has a verified local ad-hoc signature; only arm64 was run. This is not a
notarized/store build. Its independent `MUSH-mac061` save directory contains the
QA clearing. **Continue** restores that night/rain save; **Begin a new clearing**
starts over in this candidate profile. W/A/S/D walks, mouse looks, Space floats,
G glows, E interacts, B decorates, and Escape opens pause/save/settings.

## Evidence and limits

- Source gameplay: 295 assertions / 15 scenarios pass. Isolated and integrated
  surface comparisons each pass 19 checks plus eight decoded paired PNGs.
- Exported app: 12 startup/effects checks and four still captures pass. Through
  the actual UI, new game, glow, pause, weather selection, save/quit and Continue
  were observed. Both ordinary sessions exited with code 0. A single W tap is
  not sustained walking/collision or camera-feel acceptance.
- Exported 120-second night/rain route: 7,173 frames, two loops, zero stalls;
  p95 **18.522 ms**, p99 **19.447 ms**. The 16.7 ms p95 gate remains failed.
- `clip-20261011-043652/environment-smoke.mp4` is a 3.53-second, 1280 x 720
  in-engine recording, fully decoded after encoding. It uses fixed 30 FPS offline
  rendering and does not prove real-time frame pacing or accepted motion quality.
- Tests used Dummy audio. Live listening, sustained manual control/camera feel,
  final reference fidelity and physical-device testing remain pending.

The original package runner failed its smoke launch because the official template
rejects `--main-pack`. The launcher was corrected to normal bundle discovery;
the same unchanged app/ZIP then passed smoke and capture verification. Both the
failure and successful successor receipts remain in the build directory.

The temporary export stage was deleted only after exact source, admitted profile/
bundle overrides and ZIP/app readback checks; 239,607,808 allocated file bytes were
removed. Source, saves, references, prior builds and unique evidence were retained.
`DELIVERY.json` and adjacent receipts bind this local artifact. Build artifacts are
ignored by Git; the repository carries source, licenses and concise results.
