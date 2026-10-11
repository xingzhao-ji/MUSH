# Mac development candidate (mac062)

This experimental 0.6.0 app includes the weathered entrance surface, narrower
lower paving joint and restrained moonlit sky fill. It launches on the tested
Apple M4 Pro Mac. Scenery, controls and performance remain unfinished; the
accepted 0.5.7 app and 0.5.5 rollback are retained.

The source has since gained a tested narrow-joint stepping fix. That fix is not
in this mac062 app yet; run `project.godot` in Godot 4.7.2 to try the newer source.
The newer source benchmark does not qualify this frozen app.

Double-click `builds/mac-20261011-062242-26389/MUSH.app`, or run:

```sh
open builds/mac-20261011-062242-26389/MUSH.app
```

The adjacent `MUSH.zip` is 162,619,271 bytes. Its universal binary has a verified
local ad-hoc signature; only arm64 was run. It is not notarized. Saves use the new
`MUSH-mac062` directory; previous profiles remain untouched. This candidate has
no ordinary save yet: choose **Begin a new clearing**. W/A/S/D walks, mouse looks,
Space floats, G glows, E interacts, B decorates, and Escape opens pause/settings.
Use **Save & quit**, then **Continue** on the next launch.

## Verification

- Actual source gameplay: **295 assertions / 15 scenarios pass**. Environment:
  **137 checks pass**, including paused day/night changes on low/balanced quality.
- Packaged app: **12 startup/effects checks and four decoded captures pass**.
  Exported captures read back the intended daylight .05 / night .30 fill energy.
  Ten additional source comparison images cover entrance, clearing, water,
  interior and night/rain. Still images do not verify motion.
- Packaged 120-second night/rain route: **9,438 frames, two loops, zero stalls**,
  at 1920 x 1080 output with default VSync. **p95 19.521 ms / p99 28.327 ms**.
  The unchanged 16.7 ms p95 gate **fails**. CPU callback intervals are measured;
  GPU/display presentation and incremental lighting cost are not. Prior passing
  source measurements do not qualify this app.
- `verification-20261011-062513/clip/environment-smoke.mp4` beneath the build
  directory is a fully decoded 3.53-second in-engine recording. Fixed 30 FPS
  offline rendering does not prove real-time pacing or manual control feel.
- Source, prior profile metadata and app payloads remain exact across tests.
  Live listening, ordinary UI save/Continue observation for this fresh profile,
  sustained manual controls, final art and physical mobile testing remain pending.

`DELIVERY.json` and adjacent receipts bind this artifact. Temporary export staging
was removed after source/ZIP/app readback checks. The earlier mac061 app remains
at `builds/mac-20261011-042956-9202/MUSH.app`; its recorded ordinary UI checks apply
to that older app. Builds, captures and private saves remain outside Git.
