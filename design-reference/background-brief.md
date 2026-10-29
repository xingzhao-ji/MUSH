# MUSH — scenery and UI direction request for Claude

Please propose a coherent redesign direction for MUSH. This is a design discussion only: do not edit code, run the project, push, deploy, purchase, access unrelated files, or implement changes. Treat this as a separate conversation devoted to MUSH.

## User requirements

The user asks for 宏大、魔幻、温馨、独具一格: grand, magical, warm and distinctive fantasy. They want a breathtaking world that remains cozy and personal, with UI that belongs to that world. Avoid a generic plain village, generic dashboard, horror, and creepy atmosphere. Preserve the existing project's identity and functioning interactions. The user authorized sharing relevant MUSH design context and screenshots with Claude.

## Verified project identity and baseline

MUSH is the Godot clearing/home exploration game at https://github.com/xingzhao-ji/MUSH, not Hearthsign. The inspected repository identifies itself as experimental 0.6.0 source; local HEAD is e42cac7, “Preserve current tail refinement alongside versioned demo evidence.” The repository specifies Godot 4.7.2. Its separately retained 0.5.7 app remains the accepted reference; mac066 is a development candidate predating the latest tail refinement.

Core identity: a small cream woodland creature with rounded ears and a tucked round tail, mushroom homes with warm glowing oval windows, flowers and moss, stepping stones, tall forest trees, a wooden bridge and stream. It is a place to explore, plant and make a home, without combat, death or time pressure. Preserve the current creature identity rather than inventing a replacement mascot.

Two reviewed, project-only screenshots are available in docs/demos: MUSH-clearing-screenshot.png and MUSH-bridge-screenshot.png. They depict the real main scene from source 9874b92, before the current tail refinement; do not describe them as fresh runtime captures. They contain no personal information or secrets. The clearing image has a large peach mushroom cap, cream house, timber balcony, hanging foliage, glowing windows, dense trees and a centered stepping-stone approach. The bridge image shows the cream creature at a rustic bridge across a shallow stream. Both show strong high-contrast leafy shadows, busy ground texture and foliage, fairly uniform forest enclosure, and limited atmospheric depth. These are visual observations, not a full motion or play review.

Current local checkout has pre-existing deletions of baked/clearing.res and baked/clearing-renderer-neutral.res. Both are required by startup. No repair or fresh launch was attempted; do not claim the current checkout is launchable or verified. Existing documented tests are historical evidence.

## UI and interactions to preserve

Source inspection shows a Godot CanvasLayer UI with a centered scrolling PanelContainer, dark forest-green rounded panels, pale cream type, green rounded buttons, golden keyboard focus borders, a bottom-center context prompt, top-center notices, a contextual “Magic n / 100” readout, a temporary helper and center reticle. The provided scenic captures hide UI, so this UI description comes from source, not screenshots.

Preserve walking and mouse look; Space Float with hold/toggle preference; G Glow; E contextual interaction; B home decoration; Escape pause/settings/sky/weather/save. Preserve controller input, keyboard focus, key rebinding, camera preferences, reduced motion/effects, sound levels, touch controls and safe-area layout. Touch controls release on menus/lifecycle transitions.

Preserve eight garden places, six furniture places, planting previews/validation, reusable unlocked seed varieties, automatic magic regeneration, the 25-magic planting cost, immediate blooming and older-bud compatibility. Keep Begin/Continue, save recovery and persistence, garden/home progression, indoor/outdoor transitions, readable unavailable-action feedback and cancel/back behavior. Decoration currently requires being grounded inside the home. A visual redesign should not silently change rules, state, colliders or save schemas.

## Engineering guardrails

main.tscn loads scripts/playable.gd, which inherits the active planting chain in lineage/ through scripts/main.gd. The composition root creates BakedWorld, current CharacterBody player, save store, UI and environment systems. scripts/baked_world.gd loads pinned cached geometry and installs startup resources. lineage/ is active runtime inheritance, not disposable history. Authoring helpers do not necessarily run in the actual loaded scene.

Reuse existing Godot facilities and shared time/weather/material state. Keep visual motion separate from physics. Preserve collision ownership, camera corridors, window visibility, terrain traversal, original resource references, UID/import settings and asset attribution. Avoid per-frame geometry generation or a wholesale framework rewrite. Broad moss gaps, thick dark stone fronts, plain side rock/rear join, regular foliage bands, distant-window obstruction, water joins, shadows/contact and motion quality are documented art issues. A separate paving contact-coverage gate remains failed. Do not disguise these issues with effects or weaken checks.

## Optional creative hypotheses — not user mandates

Consider an intimate clearing nested beneath a monumental ancient canopy: one memorable distant crown/root silhouette, a layered midground, and a legible welcoming home in the foreground. Grandeur can come from depth, vertical scale and controlled reveals while keeping the playable clearing compact. Amber windows and cream highlights could sit within moss, soft blue distance and restrained luminous flora. Consider mushroom-gill arcs, seed-pod forms or a field-journal language as a shared UI motif, while retaining conventional readable controls. A subtle magic vessel could supplement the exact numeric value. These are suggestions for critique, not an approved design.

## Requested response

1. Diagnose the supplied project evidence and name what must remain recognizably MUSH.
2. Recommend one distinctive art direction with a clear visual thesis, composition at creature-eye level, near/mid/far scale hierarchy, focal points and day/night/weather treatment. Explain how it remains warm rather than ominous.
3. Design an integrated UI language covering exploration HUD, contextual actions, planting, decoration, pause/settings and title/continue screens. Specify materials, typography hierarchy, spacing, focus/disabled states, contrast, touch accessibility and reduced-motion behavior. Distinguish world-space decoration from readable screen-space interaction.
4. Provide a prioritized implementation plan with small reversible phases, relevant existing runtime owners, effort/risk, and measurable visual/play acceptance gates. Separate low-cost immediate wins from ambitious optional scenery work.
5. Include an explicit interaction-preservation matrix and proposed matched day/night/rain screenshots, moving-camera routes and regression checks. Do not claim tests were run.
6. End with a concrete first-pass composition brief suitable for concept art, clearly labeled proposed rather than implemented. State remaining uncertainties without blocking a useful first direction.
