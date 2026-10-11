# MUSH

A small, cozy Godot clearing to explore, plant and make a home in. This repository contains the **experimental 0.6.0 development source**, including combined paving and visual paw-contact work. It is not a newly approved release. The separately retained Mac 0.5.7 app remains recommended; 0.5.5 remains its rollback.

## Run

Use **Godot 4.7.2**, open `project.godot`, and run the main scene. The desktop test configuration is Forward+/Metal on a Mac; the latest Mac candidate misses its recorded p95 frame-time budget, with broader acceptance still open. Choose **Begin a new clearing**. Development saves use Godot's `MUSH-dev` user directory, separate from retained release profiles.

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
python3 tools/verify.py --engine /path/to/Godot --suite environment
python3 tools/verify.py --engine /path/to/Godot --suite flower-build
python3 tools/verify.py --engine /path/to/Godot --suite flower
python3 tools/verify.py --engine /path/to/Godot --suite forest-build
python3 tools/verify.py --engine /path/to/Godot --suite forest
python3 tools/verify.py --engine /path/to/Godot --suite forest-layers
python3 tools/verify.py --engine /path/to/Godot --suite outer-tree
python3 tools/verify.py --engine /path/to/Godot --suite house-foundation
python3 tools/verify.py --engine /path/to/Godot --suite home-placement
python3 tools/verify.py --engine /path/to/Godot --suite capture
python3 tools/verify.py --engine /path/to/Godot --suite paving
python3 tools/verify.py --engine /path/to/Godot --suite paving-front
python3 tools/verify.py --engine /path/to/Godot --suite shape-build
python3 tools/verify.py --engine /path/to/Godot --suite traversal
python3 tools/verify.py --engine /path/to/Godot --suite gap-step
python3 tools/verify.py --engine /path/to/Godot --suite benchmark
```

The runner writes timestamped results beneath ignored `reports/` and compresses large JSON outputs after verified readback. A tracked `reports/.gdignore` prevents screenshots from becoming imported game textures. `forest-layers` checks the installed forest, actual trunk contacts, camera clearance and ten matched stills. `outer-tree` exercises five trunk routes and native camera/bark queries through the reproduced foreground obstruction. `house-foundation` checks the installed rock support, native geometry/contact preservation and 12 paired day/night captures. `home-placement` checks the actual two-home startup installation and eight matched day/night pairs, including foliage-obscured diagnostic views; it does not prove player reachability or whole-foot terrain coverage. Runner failure paths have standard-library tests: `python3 -m unittest discover -s tests -p test_verify_runner.py`. The benchmark uses a 120-second route. See [verification evidence](docs/VERIFICATION.md) for results and the exact scope of each check; commands alone are not evidence of passing tests. The traversal suite still exits with a failed upper-soil contact-coverage gate even though all 58 movement routes pass. The separate `gap-step` suite verifies the fixed narrow-joint snag with four movement routes and ten native support cases. `shape-build` creates an isolated resource under `reports/`; `shape-capture --candidate /absolute/path/to/paving-shape.res` compares it with the installed source. Captures establish pictured states, not motion or live audio quality.

See [the tested local Mac candidate](docs/MAC-CANDIDATE.md) for its launch path, controls and remaining issues.

## Build and contribute

Install Godot 4.7.2's export templates before using the `macOS MUSH` preset. On this Mac, `python3 tools/package_mac.py --engine /path/to/Godot --candidate mac066` stages the current source into an ignored build directory, exports a separate `MUSH-mac066` candidate and checks its ZIP, signature and startup. Choose an unused `macNNN` candidate name. It requires that candidate profile to be absent and reserves 10 GiB beyond a 2 GiB output ceiling. The script downloads nothing. It writes `MUSH.app` and `MUSH.zip` beneath a timestamped `builds/mac-*` directory and uses local ad-hoc signing. The preset does not produce a notarized/store release or an iPhone build. No physical-device performance, manual controls or live listening acceptance is claimed.

Keep baked resources and `lineage/`: they are active dependencies. Generated imports, builds, reports, credentials, private saves and user reference images are excluded from Git. [Architecture](docs/ARCHITECTURE.md), [dependencies and notices](docs/DEPENDENCIES.md), [remaining work](docs/STATUS.md) and [license scope](LICENSE.md) describe the boundaries. [AGENTS.md](AGENTS.md) provides the short development workflow.
