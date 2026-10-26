# Scenery-first clearing prototype implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status (2026-10-25):** The engine was supplied after the initial blocker at
`../engine/Godot.app` (SHA256 and version match the record). Work is on branch
`prototype/scenery-first`; progress is tracked by the checkboxes below and `reports/MILESTONE.md`.

**Goal:** Turn the existing compact clearing into one cohesive amber/lavender scene: grand luminous umbrella canopies in the far layer, the warm mushroom home as an intimate foreground refuge, readable routes and depth. Do this without changing the creature, controller, collision or save semantics.

**Architecture:** Add one reversible presentation node, `PrototypeScenery`. It is a sibling of `WorldGeometry` under the main scene, so environment discovery and baked-world proofs never see it. Startup builds it once and gives it no collider or frame-time geometry. Lighting stays owned by `environment_controller.gd._apply_lighting`, which now reads its endpoints from a look dictionary. `BASELINE_LOOK` reproduces today's literals exactly. `PROTOTYPE_LOOK` carries the new grade. One project setting plus one user argument selects the look, so matched baseline and prototype captures come from the same build.

**Tech Stack:** Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, executable SHA256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf` per `docs/VERIFICATION.md`), GDScript, Forward+/Metal, Python 3 standard library.

**Spec:** `PROTOTYPE_REQUEST.md` (untracked); composition targets come from `design-reference/mush-concept-1.png` and `-2.png` (viewed, never imported).

## Runtime facts this plan relies on (inspected, not assumed)

- `main.tscn` → `scripts/playable.gd`, which extends `lineage/scenery-revision-18/proposals/planting-mana-01/candidate_main-final.gd` → … → `scripts/main.gd`.
- World: `scripts/baked_world.gd` → 21 `lineage/` files → root `lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd`. **`scripts/world.gd` is not on the active chain.**
- `baked_world.gd._ready()` instantiates `baked/clearing-renderer-neutral.res` and calls `state.restore(self)`; it does not call the chain's `_ready`/`_create_lighting`. Editing `_create_lighting` in any lineage file therefore has **no runtime effect**.
- Per-frame sun/fill/ambient/fog/exposure/sky colours are written by `scripts/environment_controller.gd:432-462` (`_apply_lighting`). That is the only lighting owner to change.
- `tests/environment_controller_contract.gd:178-196` pins fill-light energy/tint (day 0.05 `c5d4df`, night 0.30 `a5b7db`), exposure 1.0 and night practical lights at 0.9. `PROTOTYPE_LOOK` keeps these values; the contract is not edited.
- Existing `capture` suite: four 960² stills (day, night, entrance-day, entrance-night) from `review_camera`. It has no rain and no player-camera view.
- Baked proof hashes match (`original 7d9455f7…`, `derived e35b74ff…`); runner unit tests pass 8/8 (2026-10-25, no engine).

## Global Constraints

- Godot `4.7.2.stable.official.ed1daf0bf` only; `tools/verify.py` refuses other versions. No installation without user approval.
- Prototype user directory: `MUSH-proto-scenery-20261025` (checked unused 2026-10-25). Never launch with `MUSH-dev` or any retained profile.
- Budgets unchanged: benchmark p95 ≤ 16.7 ms, p99 ≤ 33.3 ms, 120-second night/rain route.
- Never edit existing assertions, baked resources, `*-proof.json`, `.uid`/`.import` files or `lineage/` files.
- No collider, physics body, gameplay force, save-schema field or per-frame geometry generation added.
- `design-reference/` is never imported, loaded by game code, or committed.
- Generated evidence goes only in ignored `reports/`. Every capture is labelled RUNTIME; concept images are labelled CONCEPT.
- No push, export, deployment or edits outside this clone. `origin` points at the original repository and must not be pushed to.
- Out of scope: battle, citizens, building editor, waterfalls/floating islands/cloud sea, Field Journal UI, new creature or home models.

## Review Focus

1. **Low tier and reduced motion:** `set_quality("low")` and `set_reduced_motion(true)` must stop the canopy shimmer and drop the optional effects while keeping light direction. Test: `prototype_look_contract` → `low_tier_and_reduced_motion_freeze`.
2. **Night warmth:** the lavender night grade must not out-glow or wash out the home's amber windows. Test: the existing `forest-layers` window sightlines still pass, plus a reviewed night pair. Any failure is reported, not tuned away silently.
3. **Pause/lifecycle:** canopy shimmer time must not advance while the tree is paused, and quitting frees the prototype's materials. Test: `prototype_look_contract` → `paused_time_frozen`.
4. **Indoor scenes:** depth fog must stay clear indoors. Test: `prototype_look_contract` → `fog_begins_beyond_clearing` (fog_depth_begin ≥ 30 m), plus `acceptance` indoor scenarios.
5. **Baseline toggle identity:** with the prototype off, every value `_apply_lighting` writes equals the pre-change literals. Test: `prototype_look_contract` → `baseline_look_identical`.

---

### Task 0: Engine gate and isolated profile — **BLOCKED (engine absent)**

**Files:**
- Modify: `project.godot:18` `config/custom_user_dir_name="MUSH-dev"` → `"MUSH-proto-scenery-20261025"`

- [ ] **Step 1:** Obtain an approved engine path. Verify that `"$ENGINE" --version` prints `4.7.2.stable.official.ed1daf0bf` and `shasum -a 256 "$ENGINE"` equals the recorded SHA256. If the SHA differs, record it and ask; never silently requalify.
- [ ] **Step 2:** Record SHA256 of `~/Library/Application Support/Godot/editor_settings-4.7.tres` and `projects.cfg`. The `import` suite runs `--editor`, so the shared editor files may change. Report any change.
- [ ] **Step 3:** Confirm `test ! -e "$HOME/Library/Application Support/MUSH-proto-scenery-20261025"`, then edit `project.godot` and commit. Message: `Isolate prototype runs in MUSH-proto-scenery-20261025 profile`. Rollback: `git revert <sha>`.
- [ ] **Step 4:** Run the baseline, unchanged except for the profile: `python3 tools/verify.py --engine "$ENGINE" --suite import`, then `acceptance`, `ground`, `environment`, `capture`, `forest-layers`, `benchmark` (one suite per invocation). Expected: 295/295, ground 32/32, environment contract passes, 4 capture stills, 29 forest checks, benchmark within budget. Preserve any failure as found.

### Task 1: Matched scenic capture suite + baseline evidence (Milestone 1)

**Files:**
- Create: `tests/scenic_capture.gd` (+ its generated `.uid` from import)
- Modify: `tools/verify.py` (add `"scenic"` to `--suite` choices; command `--resolution 1280x720 --script res://tests/scenic_capture.gd -- --report-dir=<out>/native` plus a new `--prototype-scenery {on,off}` runner option appended as the user arg `--prototype-scenery=<value>` (accepted only for `scenic`/`prototype`; before Task 2 it has no effect, so M1 captures show the unchanged HEAD scene); inspect branch reuses the existing full-PNG-decode code from the `capture` branch at `tools/verify.py:428-441`)
- Create: `tools/compare_sheet.py` (stdlib only; writes `reports/<run>/compare.html`)
- Test: `tests/test_verify_runner.py` (add `test_scenic_suite_requires_all_views`)

**Interfaces:**
- Produces: report `native/scenic.json`, schema `mush-scenic-capture/1`, with `views[]` rows `{file, view, appearance, look, camera_position, target, fov, rgba_sha256, canopy_fraction, clipped_fraction, hud_fraction|null, player_floor}` and `passed`.
- Produces views (1280×720): `scenic-home` (review camera (6,3.3,20) → (3.2,1.65,0), fov 60); `scenic-vista` (start at (8,6.5,26) → (18,14,-60), fov 55; the pose is tuned once in Task 3 and frozen in the report); `ground-path` (actual player `_camera` after `teleport_safe(Vector3(-2,0.08,18), yaw)` facing the world origin); `ground-bridge` (player 3 m on the south side of the bridge-deck AABB centre found via `world.find_child("*ridge*", true, false)`, facing it). Each view is captured in `day`, `night` and `rain` (rain = day + rain), 12 images. Add one `ground-path-day-hud` with the UI shown, for 13 total.

- [ ] **Step 1: Failing runner test.** `test_scenic_suite_requires_all_views`: an inspect on a fixture report with 12 of 13 PNGs must raise; with 13 valid PNGs and `passed: true` it returns `full_png_decodes` of length 13 and `motion_verified: False`.
- [ ] **Step 2:** `python3 -m unittest discover -s tests -p test_verify_runner.py` → the new test FAILS.
- [ ] **Step 3:** Implement the verify.py branch and `tests/scenic_capture.gd`. Boot the game as `tests/forest_layers.gd:18` does. Hide the UI except for the HUD view, set `player.enabled=false`, call `world.set_living_motion_enabled(false)` and set `_time=0`, call `set_appearance(night, rain, false)`, wait 4.0 s, then two `RenderingServer.force_draw()` cycles before reading back. Per view, assert: saved OK, size 1280×720, `player.is_on_floor()`, and for `ground-*` the home cap/bridge centre `is_position_in_frustum`. `clipped_fraction` = share of pixels with every channel ≥ 254 or ≤ 1. `hud_fraction` = share of pixels differing (any channel > 3/255) between the HUD-shown and HUD-hidden frames of the same frozen state. `canopy_fraction` is `null` until Task 3.
- [ ] **Step 4:** The unit tests pass. Then `python3 tools/verify.py --engine "$ENGINE" --suite scenic` → 13 decoded PNGs, `passed: true`.
- [ ] **Step 5:** `python3 tools/compare_sheet.py reports/<run>` → `compare.html`. CONCEPT images are referenced by path in a separate column headed "CONCEPT — not runtime"; runtime columns are headed "RUNTIME — Godot 4.7.2 capture". No image is copied into the project.
- [ ] **Step 6:** Commit (`tests/scenic_capture.gd`, its `.uid`, `tools/verify.py`, `tools/compare_sheet.py`, `tests/test_verify_runner.py`). Write `reports/MILESTONE.md` "M1 baseline" with the exact PNG paths, suite results and the visual deviations listed against the composition checklist below.

### Task 2: Look profile in the lighting owner (pure refactor)

**Files:**
- Create: `scripts/prototype_scenery.gd` (static `is_enabled()` only in this task)
- Modify: `scripts/environment_controller.gd:432-462`; `project.godot` (add `[mush] prototype/scenery=true`)
- Create: `tests/prototype_look_contract.gd`; register suite `prototype` in `tools/verify.py` (`--script res://tests/prototype_look_contract.gd`)

**Interfaces:**
- Produces: `PrototypeScenery.is_enabled() -> bool`. It returns `ProjectSettings.get_setting("mush/prototype/scenery", false)`, unless the user args contain `--prototype-scenery=off` (→ false) or `=on` (→ true).
- Produces: in `environment_controller.gd`, `const BASELINE_LOOK: Dictionary` holding every literal now in `_apply_lighting`, `const PROTOTYPE_LOOK: Dictionary` (same keys plus `fog_depth_begin`, `fog_depth_end`, `fog_aerial_perspective`, `sun_angular_distance`), and `var look: Dictionary` chosen in `configure()`.

- [ ] **Step 1: Failing test** `baseline_look_identical`. With `--prototype-scenery=off`, for night ∈ {0, 1}, rain ∈ {0, 1} and sunset ∈ {0, 1}, every property written by `_apply_lighting` equals a frozen copy of today's expressions evaluated inside the test (sun colour/energy/rotation, fill, ambient, fog colour/density, exposure, sky top/horizon).
- [ ] **Step 2:** Run `--suite prototype` → FAIL (no `look`).
- [ ] **Step 3:** Refactor `_apply_lighting` to read `look[...]`. In this task `PROTOTYPE_LOOK` is a copy of `BASELINE_LOOK`.
- [ ] **Step 4:** `--suite prototype` passes. Rerun `environment` and `ground` unchanged; both pass.
- [ ] **Step 5:** Commit. Rollback: `git revert`.

### Task 3: Far luminous canopy layer and depth layering (Milestone 2)

**Files:**
- Modify: `scripts/prototype_scenery.gd`; `scripts/playable.gd` (after `environment_controller` is added: `if PrototypeScenery.is_enabled(): prototype_scenery = PrototypeScenery.new(); add_child(prototype_scenery); prototype_scenery.configure(world)`)
- Create: `assets/world/far_canopy.gdshader`
- Modify: `tests/scenic_capture.gd` (fill `canopy_fraction`); `tests/prototype_look_contract.gd`

**Interfaces:**
- Produces: `configure(world: Node3D) -> void`; `set_state(night: float, rain: float, reduced_motion: bool, quality: String) -> void`; `set_frozen(frozen: bool) -> void`; `set_debug_mask(enabled: bool) -> void` (swaps in an unshaded, `fog_disabled`, flat `#ff00ff` override); `get_report() -> Dictionary` with keys `passed, canopies, triangles, draw_nodes, colliders, shadow_casters, built_at_startup_only`.
- Consumes: `playable.gd` declares `const PrototypeScenery = preload("res://scripts/prototype_scenery.gd")` and `var prototype_scenery: Node3D`. `environment_controller._apply_lighting` reads `game.get("prototype_scenery")` and calls `set_state` only when it is a valid instance (one uniform write per call).

Geometry, built once in `configure`:
- One lathe `ArrayMesh` via `SurfaceTool` (`_build_canopy_mesh(segments := 48, rings := 12) -> ArrayMesh`): a domed umbrella top and a concave gill underside with radial gill ridges in vertex colour. One tapered stem `CylinderMesh` (radial_segments 24) with a root flare.
- Two `MultiMeshInstance3D` (caps, stems): 3 hero canopies (cap radius 45–70 m, height 95–140 m, 230–420 m away) and 6 secondary (radius 12–25 m, 140–320 m away). Place them in the sector beyond the home and to its right as seen from spawn, matching concept 1 (home left, giants right). `cast_shadow = OFF`, no collision; uses a visual layer, not physics layers 1–6.
- `far_canopy.gdshader`: gill underside emission grades amber at the rim → lavender at the centre. The top takes rim light from the sun direction. The stem fades into the fog colour below 25 m height. Shimmer uses a `time` uniform owned by `PrototypeScenery` (frozen on pause, reduced motion or capture).
- Layering: `PROTOTYPE_LOOK` turns on depth fog (`fog_mode = FOG_MODE_DEPTH`, `fog_depth_begin` 32 m, `fog_depth_end` 520 m, `fog_aerial_perspective` 0.6), so the clearing stays crisp while the forest ring and the giants recede.

- [ ] **Step 1: Failing tests.** `prototype_report_static` (colliders 0, shadow_casters 0, draw_nodes 2, canopies 9, triangles < 40,000; report unchanged after 120 processed frames); `fog_begins_beyond_clearing`; `paused_time_frozen`; `low_tier_and_reduced_motion_freeze`.
- [ ] **Step 2:** `--suite prototype` → FAIL.
- [ ] **Step 3:** Implement as above.
- [ ] **Step 4:** `--suite prototype` passes. `--suite scenic` reports `canopy_fraction` (debug-mask pixels / frame) ≥ 0.03 in `ground-path-day` and ≥ 0.06 in `scenic-vista-day`. Tune the placement (not the threshold) until it does, and record the final pose in the report.
- [ ] **Step 5:** Run `acceptance`, `forest-layers` and `home-placement` unchanged. Then `--suite scenic` with `--prototype-scenery=off` and `=on` for the matched pairs. Commit, and write `reports/MILESTONE.md` "M2 revised scene".

### Task 4: Amber/lavender lighting and material pass (Milestone 3)

**Files:**
- Modify: `scripts/environment_controller.gd` (`PROTOTYPE_LOOK` values only); `scripts/prototype_scenery.gd` (≤ 3 warm `OmniLight3D` refuge pools at the porch and path entry, `shadow_enabled=false`, range ≤ 5 m, energy scaled up at night); `assets/world/clearing_sky.gdshader` (new uniforms `ridge_color`, `ridge_amount` default 0.0, a distant lavender ridge band from azimuth noise, with baseline output unchanged at 0.0)
- Test: `tests/prototype_look_contract.gd`

`PROTOTYPE_LOOK` starting values (tuned only against captures, with each change recorded):
- Day: sun `ffb877` pitch −16° energy 1.25, `sun_angular_distance` 2.5 (softer leaf shadows); ambient `cbb8d6` energy 0.34; sky top `7c78bd`, horizon `f1b58f`; fog `b9a6cf`.
- Night: sun `9aa6e8` energy 0.55; ambient `8e8fc4` energy 0.30; sky top `141a44`, horizon `3a3466`; fog `2c2b52`; canopy emission ×2.2.
- Rain: fog `9d97b3`, density +0.004; canopy emission ×0.7.
- Fill and exposure stay exactly as pinned.

- [ ] **Step 1: Failing tests.** `prototype_keeps_pinned_fill` (fill energy/tint and exposure equal the contract values for both looks); `refuge_lights_static` (≤ 3 lights, no shadows, positions within 6 m of the home door); `ridge_default_is_baseline` (`ridge_amount` 0.0 with the prototype off).
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** `prototype`, `environment`, `ground` and `scenic` pass. `clipped_fraction` ≤ 0.02 in all 12 views. `hud_fraction` ≤ 0.06.
- [ ] **Step 5:** Commit, and write `reports/MILESTONE.md` "M3 lighting/material".

### Task 5: Integration, regression, comparison and docs (Milestone 4)

**Files:**
- Modify: `docs/STATUS.md`, `docs/VERIFICATION.md` (new short section), `README.md` (one paragraph: toggle, profile, scope)

- [ ] **Step 1:** Run each suite once, unchanged: `import`, `acceptance`, `ground`, `environment`, `capture`, `forest-layers`, `home-placement`, `prototype`, `scenic` (off and on), `benchmark`. Expected: 295/295, contracts pass, benchmark p95 ≤ 16.7 / p99 ≤ 33.3. Failures stay recorded with receipts.
- [ ] **Step 2:** Run `compare_sheet.py` on the final pair. Read every runtime PNG, then list deviations against the composition checklist below and fix any obvious gap via Tasks 3–4 values (with rerun).
- [ ] **Step 3:** Check the `git diff`/payload: no `design-reference/`, engine, profile, report or build files. `SOURCE_MANIFEST.json` is left untouched unless its own tool regenerates it.
- [ ] **Step 4:** Commit the docs. Write `reports/MILESTONE.md` "M4 final" with the change list, launch command (`"$ENGINE" --path . --rendering-driver metal`), screenshot paths, results and limits.

## Composition checklist (from concepts; used at every milestone)

1. The warm home holds the left/centre foreground, and its windows are the warmest values in the frame.
2. A readable path leads from the bottom of the frame into the midground.
3. The largest luminous canopy sits upper-right and overlaps the sky; its underside glows.
4. Far elements are lower in contrast and tinted lavender; the mid forest ring is separated from the far layer by haze.
5. The sky runs from a peach horizon to a lavender top (day), or lavender to indigo (night).
6. Foreground framing at the edges never hides the home or the creature.
7. Leaf shadows are softened, not high-contrast noon stripes.

## Disclosed limits

- Captures show only depicted still states, not motion, audio, device performance or manual feel.
- No AAA parity claim.
- The concepts' waterfalls, floating islands, arched bridges, cloud sea and Field Journal UI are out of scope.
