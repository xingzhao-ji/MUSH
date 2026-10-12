# MUSH

A small, cozy Godot clearing to explore, plant and make a home in. This repository contains the **experimental 0.6.0 development source**, including combined paving and visual paw-contact work. It is not a newly approved release. The separately retained Mac 0.5.7 app remains recommended; 0.5.5 remains its rollback.

## Source, playable artifacts and engineering scope

- [Source repository](https://github.com/xingzhao-ji/MUSH) and [mac066 Mac candidate](https://github.com/xingzhao-ji/MUSH/releases/tag/mac066). The candidate is a real exported game, with the limitations recorded below. A separate [versioned browser build](https://xingzhao-ji.github.io/my_site/demos/mush/index.html) is now published; its pinned source and desktop WebGL 2 requirements are described below.
- Project work includes GDScript gameplay and movement, bounded save validation/recovery, cached procedural geometry, shared environmental rendering state, and reproducible verification tools. Godot supplies the engine, physics and rendering facilities. [Asset credits](assets/credits.json) distinguish original procedural content from third-party music, sounds and textures.
- This is a development prototype. The repository does not claim external adoption, an upstream Godot contribution, a shipped mobile product or a blanket open-source license. The project owner confirmed original creation of the bark/moss assets; [LICENSE.md](LICENSE.md) records the provenance clarification and unchanged third-party terms.

### Runtime map

| Component | Responsibility | Source |
| --- | --- | --- |
| Main scene and composition | Load the clearing, player, UI, save store and environmental systems | [main.tscn](main.tscn), [playable.gd](scripts/playable.gd) |
| World and baked resources | Load pinned meshes/colliders and retain original references for rollback | [baked_world.gd](scripts/baked_world.gd), [baked/](baked/) |
| Player and paw presentation | Keep CharacterBody movement separate from visual foot/bone adjustment | [player.gd](scripts/player.gd), [paw_grounding.gd](scripts/paw_grounding.gd) |
| Save store | Validate bounded state, verify writes and recover from a validated backup | [save_store.gd](scripts/save_store.gd) |
| Shared environment | Coordinate time, weather, material state and reduced-motion settings | [environment_controller.gd](scripts/environment_controller.gd) |
| Verification and packaging | Run native checks, preserve failed receipts, and build isolated Mac candidates | [tools/verify.py](tools/verify.py), [tools/package_mac.py](tools/package_mac.py) |

The active inheritance chain in `lineage/` is required at runtime. See the full
[architecture](docs/ARCHITECTURE.md) for startup dependencies and bounded-work
tradeoffs.

## Recorded demo

[Watch the 12-second engine capture](docs/demos/MUSH-gameplay-demo.mp4) or browse
the [clearing and bridge screenshots](docs/demos/README.md). This is the real
main scene captured from source `9874b92`, before the current tail refinement,
with Godot 4.7.2 MovieWriter at 1280 × 720 and 15 fps on a cloud software
renderer. Rendering ran slower than playback, so the clip does
not establish real-time performance or manual-play acceptance. It contains an
audio track; listening quality was not reviewed during publication.
The [15-minute technical-demo runbook](docs/demos/MUSH-15-minute-demo-runbook.txt)
is a presentation plan, not the length of the recording.

[![MUSH's clearing and mushroom home](docs/demos/MUSH-clearing-screenshot.png)](docs/demos/MUSH-gameplay-demo.mp4)

## Run

Clone the public repository, then open the project:

```sh
git clone https://github.com/xingzhao-ji/MUSH.git
cd MUSH
```

Use **Godot 4.7.2**, open `project.godot`, and run the main scene. The desktop test configuration is Forward+/Metal on a Mac. The new mac066 candidate clears the sampled third-home canopy views and passes its 120-second benchmark with verified engine draw progress. The source passes 295 gameplay assertions and 29 forest checks; the app passes 12 startup checks and four still captures. Full art and manual-play acceptance remain open. Choose **Begin a new clearing**. Development saves use Godot's `MUSH-dev` user directory, separate from retained release profiles.

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

Current source also refines the cream creature’s tail into one smooth, tucked
volume, removing five mesh nodes. Fresh source checks pass 295 gameplay assertions
and the 120-second benchmark (p95 12.275 ms / p99 13.640 ms). Earlier failed
attempts and the scope of the input-diagnostic run remain in
[verification evidence](docs/VERIFICATION.md). The downloadable mac066 app
predates this source refinement.

## Browser build

[Open the versioned browser build](https://xingzhao-ji.github.io/my_site/demos/mush/index.html). A desktop browser with WebGL 2 is required; the first download is large and shader compilation can take time.

The original Godot game has a versioned, single-threaded WebGL 2 export with local browser saves. See [web build, controls, hosting and verification](docs/WEB-DEMO.md). The browser demo is pinned to tested source `9874b92`, before the current single-tail refinement; it does not replace newer native source. Browser performance and whole-game acceptance remain separate checks.

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

The runner writes timestamped results beneath ignored `reports/` and compresses large JSON outputs after verified readback. Tracked `reports/.gdignore` and `builds/.gdignore` prevent test screenshots and exported outputs from becoming imported game assets. `forest-layers` checks the installed forest, ten static window sightlines, actual trunk contacts, camera clearance and ten matched stills. The installed trees 6, 7 and 8 now use the existing tall cohort to expose the third home, with roots, RNG order and shared resources retained. Two explicit redraws qualify each frozen still; this is not motion or display-presentation evidence. `outer-tree` exercises five trunk routes and native camera/bark queries through the reproduced foreground obstruction. `house-foundation` checks the installed rock support, native geometry/contact preservation and 12 paired day/night captures. `home-placement` checks the actual two-home startup installation and eight matched day/night pairs, including foliage-obscured diagnostic views; it does not prove player reachability or whole-foot terrain coverage. Runner failure paths have standard-library tests: `python3 -m unittest discover -s tests -p test_verify_runner.py`. The benchmark uses a 120-second route. See [verification evidence](docs/VERIFICATION.md) for results and the exact scope of each check; commands alone are not evidence of passing tests. The traversal suite still exits with a failed upper-soil contact-coverage gate even though all 58 movement routes pass. The separate `gap-step` suite verifies the fixed narrow-joint snag with four movement routes and ten native support cases. `shape-build` creates an isolated resource under `reports/`; `shape-capture --candidate /absolute/path/to/paving-shape.res` compares it with the installed source. Captures establish pictured states, not motion or live audio quality.

See [the tested local Mac candidate](docs/MAC-CANDIDATE.md) for its launch path, controls and remaining issues.

### Reading the results

The October 11, 2026 source checkpoint `b5c9f61` records 295 gameplay assertions
across 15 scenarios and 29 forest checks. Its 120-second night/rain source route
at 1920 × 1080 with default VSync records p95 **11.575 ms** and p99 **13.188 ms**,
two loops and zero stalls. The benchmark validates route completion and engine
draw progress, then recomputes percentiles from the recorded callback intervals.
It measures application frame callbacks, not GPU duration or display presentation.

The mac066 exported 120-second route passes p95 **10.619 ms** / p99 **13.759 ms**,
with 15,177 samples, two loops, no stalls and verified engine draw advancement.
Its first screenshot phase timed out; a separate topmost-window retry passes all
four stills. The failed receipt is retained.

The older separately exported mac065 candidate records p95 **17.524 ms**, exceeding the
unchanged 16.7 ms budget. The paving contact-coverage gate also remains failed.
Source and export results qualify their own artifacts; they do not establish a
causal speedup or physical-phone performance. These are recorded results, not a
claim that documentation edits reran the game. Continuous manual motion, live
listening and whole-game art acceptance remain open. Full scope, hardware and
historical failures are preserved in [VERIFICATION.md](docs/VERIFICATION.md).

## Build and contribute

Install Godot 4.7.2's export templates before using the `macOS MUSH` preset. On this Mac, `python3 tools/package_mac.py --engine /path/to/Godot --candidate mac067` stages the current source into an ignored build directory, exports a separate `MUSH-mac067` candidate and checks its ZIP, signature and startup. Choose an unused `macNNN` candidate name. It requires that candidate profile to be absent and reserves 10 GiB beyond a 2 GiB output ceiling. The script downloads nothing. It writes `MUSH.app` and `MUSH.zip` beneath a timestamped `builds/mac-*` directory and uses local ad-hoc signing. The preset does not produce a notarized/store release or an iPhone build. No physical-device performance, manual controls or live listening acceptance is claimed.

Keep baked resources and `lineage/`: they are active dependencies. Generated imports, builds, reports, credentials, private saves and user reference images are excluded from Git. [Architecture](docs/ARCHITECTURE.md), [dependencies and notices](docs/DEPENDENCIES.md), [remaining work](docs/STATUS.md) and [license scope](LICENSE.md) describe the boundaries. [AGENTS.md](AGENTS.md) provides the short development workflow.

