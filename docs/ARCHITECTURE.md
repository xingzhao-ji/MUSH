# Runtime and storage architecture

`main.tscn` loads `scripts/playable.gd`. That composition root creates the baked World, current CharacterBody player, save store, UI, environment coordinator and visual paw modifier. Gameplay physics stays separate from shader animation and bone presentation.

`lineage/` contains active inheritance, not discarded trial copies. Main inherits the planting interaction chain; World inherits the scenery and living-motion chain; the current player inherits the camera/step controller. Preserve these paths until a separately tested extraction replaces each dependency.

## World resources

`scripts/baked_world.gd` loads the renderer-neutral clearing and installs prebuilt cap, plaster, paving, floor, soil and roof resources through existing owners. Loaders verify pinned payloads and preserve original references for rollback. The combined preview swaps existing mesh/shape references; it adds no paving body or per-frame geometry generation.

Both `baked/clearing.res` and `baked/clearing-renderer-neutral.res` are required by the current startup proof. Their roughly 64 MB sizes do not justify deleting one: startup hashes the retained original and derived resource. Proof JSON may contain historical workstation paths as provenance; those records are not instructions to load external source files. Do not rewrite a proof merely to remove historical metadata.

## Cost and complexity

These are source-level bounds, not GPU or device measurements. Let `N` be geometry nodes, `M` bound materials, `P` particle systems, `F` restoration flora, `V` root-material variants, `U` their ordinary shader parameters, `G` garden plants and `B` bytes admitted by startup checks.

| Operation | Work and retained state | Bound or tradeoff |
| --- | --- | --- |
| Baked startup and proofs | O(B) byte validation plus engine deserialization | Kept out of the frame loop; rollback retains original resources. |
| Environment update | O(M + P + F + VU) script work per active frame | Fixed uniform set per material; V <= 32. Rendering cost depends on the submitted scene. |
| Environment discovery | Scene traversal plus first-seen mesh/channel checks and instance admission | Cached mesh identities avoid repeating native channel comparison every frame; discovery and update are distinct costs. |
| Garden placement and rebuilding | O(G) validation/rebuild work and O(G) plant state | G <= 8; a spatial index would add machinery without removing a present scaling problem. Placement also performs one native ray query. |
| Paw presentation | Two grounded ray queries and two bounded pose adjustments per physics tick; O(1) script state | Native query cost is scene-dependent. One sampled plane per foot does not establish whole-foot terrain conformity. |
| Report/storage checks | Linear in bytes hashed | Measurements belong in ignored reports, with compact summaries retained in documentation. |

CPU complexity does not prove good frame pacing. Transparency, shadows, particles and resolution can dominate GPU time even when script loops are bounded. [VERIFICATION.md](VERIFICATION.md) records measured observations and limits.

The narrow material-forwarding cleanup replaces a copied dictionary-values array with direct dictionary iteration. Forwarding remains O(VU); the avoidable O(V) temporary array becomes O(1) iterator state. V is already capped at 32. This is a bounded allocation reduction, not evidence of a measurable frame-time gain; native parity and fresh benchmark results must establish the actual outcome.

## Environment approximations

The coordinator shares direction, gust strength, clock, wetness, cloud offset and player position across existing materials. Quality tiers preserve lighting direction; reduced motion scales detail. Visual deltas are clamped and lifecycle handling freezes accumulated motion. Gameplay does not receive environmental knockback.

Cloud shade is material/albedo modulation. Rain shelter uses authored masks rather than a collision body per drop. Rooted vegetation is admitted against known source meshes; mixed baked geometry without proven roots stays static. Particle `amount_ratio` reduces visible emission, not allocated capacity. Emissive surfaces provide visual glow; only actual light nodes illuminate nearby geometry. Hanging baked architecture remains static.

## Repository boundary

Track source assets, `.import` settings, `.uid` files, required baked resources, portable tests, notices and concise documentation. Ignore `.godot/`, builds, full reports, private export credentials and local environment files. Keep historical app archives and review evidence in the existing local archive, outside this repository. Do not commit the engine, export templates, private profiles or user reference-image package.
