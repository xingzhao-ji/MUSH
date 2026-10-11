# MUSH

A small, cozy Godot clearing to explore, plant and make a home in. This repository contains the **experimental 0.6.0 development source**, including combined paving and visual paw-contact work. It is not a newly approved release. The separately retained Mac 0.5.7 app remains recommended; 0.5.5 remains its rollback.

## Run

Use **Godot 4.7.2**, open `project.godot`, and run the main scene. The qualified desktop configuration is Forward+/Metal on a Mac. Choose **Begin a new clearing**. Development saves use Godot's `MUSH-dev` user directory, separate from retained release profiles.

| Input | Action |
| --- | --- |
| W/A/S/D | Walk |
| Mouse | Look |
| Space | Hold Float; toggle mode is available in Settings |
| G | Toggle Glow |
| E | Use the displayed interaction |
| B | Decorate inside the home |
| Escape | Pause, settings, sky/weather and save |

Settings include reduced motion/effects, camera preferences, sound levels and key rebinding. The garden has eight places; the home has six furniture places. There is no combat, death or time pressure.

## Verify

Python 3 and the matching Godot executable are required. Close the game/editor before testing and retain 10 GiB of free disk space. Run the import suite first on a clean checkout. From the repository root:

```sh
python3 tools/verify.py --engine /path/to/Godot --suite import
python3 tools/verify.py --engine /path/to/Godot --suite acceptance
python3 tools/verify.py --engine /path/to/Godot --suite ground
python3 tools/verify.py --engine /path/to/Godot --suite capture
python3 tools/verify.py --engine /path/to/Godot --suite benchmark
```

The runner writes timestamped results beneath ignored `reports/`. The benchmark uses a 120-second route. See [verification evidence](docs/VERIFICATION.md) for results and the exact scope of each check; commands alone are not evidence of passing tests. Captures establish pictured states, not motion or live audio quality.

## Build and contribute

Install Godot 4.7.2's export templates before using the `macOS MUSH` preset. It writes `builds/MUSH.zip` and uses local ad-hoc signing. The preset does not produce a notarized/store release or an iPhone build. No physical-device performance, manual controls or live listening acceptance is claimed.

Keep baked resources and `lineage/`: they are active dependencies. Generated imports, builds, reports, credentials, private saves and user reference images are excluded from Git. [Architecture](docs/ARCHITECTURE.md), [dependencies and notices](docs/DEPENDENCIES.md), [remaining work](docs/STATUS.md) and [license scope](LICENSE.md) describe the boundaries. [AGENTS.md](AGENTS.md) provides the short development workflow.
