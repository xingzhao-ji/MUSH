# Walkable route + open overlook: minimal collider plan (PLAN ONLY — not implemented)

Status 2026-10-26: inspection only. The current far layer (`scripts/prototype_scenery.gd`) has zero colliders; the terrain, lake and overlook ledge cannot be walked. Checkpoint commit `7d12d2c` is preserved. Wait for the Opus architecture review before broad composition/material changes.

## Findings from the actual source
- Real ground collision ends at the old clearing edge: physics rays hit ground only inside about x ±25, z −22…28 (y 0.04–0.59); beyond that nothing is hit (`reports/scenic-20261026-000731-62897/scenic.json`, `ground_probe`).
- `scripts/player.gd:443` `_outside_playable()` hardcodes x −20…20, z −20…26. It drives recovery (line 119, 360), safe-position validation (392) and teleport resolution (266, 410). Colliders alone therefore cannot make a route walkable: the player would be recovered to `FIXED_RECOVERY (-2,0,12)`.
- Player mask is `WORLD_MASK = 1|4|16`; camera mask adds 32. A new route body on layer 1 collides with both the player and the camera spring arm.
- Visual terrain near the clearing sits at y −1.5 (hidden under the old soil). A collider at walking height would float above it unless the route has its own embankment mesh.

## Minimal safe scope (proposed)
1. **One `StaticBody3D` "NearRouteCollision", layer 1, one `ConcavePolygonShape3D`**, built once at startup from a ribbon (4 m flat tread, 3 m shoulders at ≤27°) following a curved centreline from (−2, 29) to the ledge top near (−30, 215). It starts exactly on the old collider seam z = 29 (y 0.04) and never overlaps or edits baked colliders. Surface height = `terrain_height(x,z)` lifted by a smooth blend from 0.04 at the seam to the terrain at z ≥ 90. A matching visual ribbon (moss/earth, same mesh as the collider) hides the 1.5 m gap.
2. **Default-neutral playable extension:** add `var extra_playable_zones: Array[AABB] = []` to the player class and make `_outside_playable()` return false inside any registered zone. Empty by default, so baseline behaviour, saves and all 295 assertions are untouched. `PrototypeScenery` registers a corridor AABB around the route and the ledge only when enabled.
3. **Leave saves alone:** do not allow safe-save positions outside the original bounds until saving there is separately designed. The route is explorable but the save marker stays inside the old playable box (extra zones count as "playable" for movement only).
4. **No overlook rails/buildings/ownership.** Ledge rocks stay visual unless they block the route.

## Proportionate tests (when implemented)
- Native: CharacterBody traversal along the route centreline and both shoulders using the real installed collider (not rays alone): reaches the ledge, `is_on_floor()` throughout, no recovery event, no frame with the camera inside terrain.
- Regression: acceptance 295/295 unchanged with the prototype on and with `--prototype-scenery=off`; `traversal` suite status compared with its documented baseline (known failed upper-soil gate stays failed).
- Camera: spring-arm samples along the route; far plane 1400 m already set.
- Performance: one fresh 120-second `benchmark` after the collider is added (budget p95 ≤ 16.7 ms).
- Manual movement/camera feel stays UNVERIFIED until a person plays it.

## Not in scope
Buildings, citizens, ownership, KING Mushroom, water/lake wading, climbing outside the route.
