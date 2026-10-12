# Runtime and storage architecture

`main.tscn` loads `scripts/playable.gd`. That composition root creates the baked World, current CharacterBody player, save store, UI, environment coordinator and visual paw modifier. Gameplay physics stays separate from shader animation and bone presentation.

`lineage/` contains active inheritance, not discarded trial copies. Main inherits the planting interaction chain; World inherits the scenery and living-motion chain; the current player inherits the camera/step controller. Preserve these paths until a separately tested extraction replaces each dependency.

The cream creature now uses one tucked tail ellipsoid, omitting five separate
tuft mesh constructions. Its 24 registered meshes contain 26,112 triangles.
Existing skeleton, clips, material and per-frame fade are reused; no fur system
or new physics is introduced. Construction/fade remain O(M) in the fixed mesh
count M. The five-node reduction does not establish a frame-time or memory gain.

## World resources

`scripts/baked_world.gd` loads the renderer-neutral clearing and installs prebuilt cap, plaster, paving, floor, soil and roof resources through existing owners. Loaders verify pinned payloads and preserve original references for rollback. The combined preview swaps existing mesh/shape references; it adds no paving body or per-frame geometry generation. Two shallow entrance material forks now reuse the reviewed Rock01 albedo at startup, before both paving owners capture their selected materials. The top keeps one planar sample. The new front fork uses the existing three-sample world-space triplanar branch across all 3,078 front corners, including the retained 2,598-corner prefix. The startup report names its counts pre_geometry_install_batch_corners (972 top / 2,526 front); fixture readback verifies the final installed batches at 4,638 top / 3,078 front corners. Original material pointers remain available, other aliases keep their references, and ordinary environmental discovery forwards clock/cloud/wetness uniforms. Relative to the previous source, this adds one static material and three front albedo samples, with no new texture asset, draw node, geometry, collision or script frame loop; existing environmental bindings remain active. Shader cost depends on visible front pixels and is not a GPU or mobile measurement. The baked paving resource remains unchanged; the separate front-return geometry candidate was rejected at art review.

Both `baked/clearing.res` and `baked/clearing-renderer-neutral.res` are required by the current startup proof. Their roughly 64 MB sizes do not justify deleting one: startup hashes the retained original and derived resource. Proof JSON may contain historical workstation paths as provenance; those records are not instructions to load external source files. Do not rewrite a proof merely to remove historical metadata.

## Cost and complexity

These are source-level bounds, not GPU or device measurements. Let `N` be geometry nodes, `M` bound materials, `P` particle systems, `F` restoration flora, `V` root-material variants, `U` their ordinary shader parameters, `G` garden plants and `B` bytes admitted by startup checks.

| Operation | Work and retained state | Bound or tradeoff |
| --- | --- | --- |
| Baked startup and proofs | O(B) byte validation plus engine deserialization | Kept out of the frame loop; rollback retains original resources. |
| Environment update | O(M + P + F + VU) script work per active frame | Fixed uniform set per material; V <= 32. Rendering cost depends on the submitted scene. |
| Environment discovery | Scene traversal plus first-seen mesh/channel checks and instance admission | Cached mesh identities avoid repeating native channel comparison every frame; discovery and update are distinct costs. |
| Garden placement and rebuilding | O(G) placement/rebuild work and O(G) plant state | G <= 8; placement also performs one native ray query. |
| Save validation of garden overlap | O(G²) pair comparisons and O(G) positions/ID storage | The cap of 8 plants limits the nested overlap check to 28 pairs; no unbounded garden growth. |
| Paw presentation | Two grounded ray queries, up to four sphere-support evaluations and two bounded pose adjustments per physics tick; O(1) script state | Native query cost is scene-dependent. One sampled plane per foot does not establish whole-foot terrain conformity. |
| Report/storage checks | Linear in bytes hashed | Measurements belong in ignored reports, with compact summaries retained in documentation. |

CPU complexity does not prove good frame pacing. Transparency, shadows, particles and resolution can dominate GPU time even when script loops are bounded. [VERIFICATION.md](VERIFICATION.md) records measured observations and limits.

The narrow material-forwarding cleanup replaces a copied dictionary-values array with direct dictionary iteration. Forwarding remains O(VU); the avoidable O(V) temporary array becomes O(1) iterator state. V is already capped at 32. This is a bounded allocation reduction, not evidence of a measurable frame-time gain; native parity and fresh benchmark results must establish the actual outcome.

## Environment approximations

The coordinator shares direction, gust strength, clock, wetness, cloud offset and player position across existing materials. Quality tiers preserve lighting direction; reduced motion scales detail. Visual deltas are clamped and lifecycle handling freezes accumulated motion. Gameplay does not receive environmental knockback.

Cloud shade is material/albedo modulation. Rain shelter uses authored masks rather than a collision body per drop. Rooted vegetation is admitted against known source meshes; mixed baked geometry without proven roots stays static. Particle `amount_ratio` reduces visible emission, not allocated capacity. Emissive surfaces provide visual glow; only actual light nodes illuminate nearby geometry. Hanging baked architecture remains static.

## Repository boundary

Track source assets, `.import` settings, `.uid` files, required baked resources, portable tests, notices and concise documentation. Ignore `.godot/`, builds, full reports, private export credentials and local environment files. Keep historical app archives and review evidence in the existing local archive, outside this repository. Do not commit the engine, export templates, private profiles or user reference-image package.

The entrance preview now loads `baked/paving-joints.res` through the same owner. Both narrowed joints are authored offline with existing native mesh/geometry helpers. The 52-face upper soil patch refits shared boundaries and locally retriangulates three faces through Godot Geometry2D; render and contact triangles match. The small authoring validator uses O(T² + E²) pair checks for triangle/edge counts T and E, with linear stored mesh channels. These checks run during authoring/admission, never in the frame loop. Seven existing scalar geometry predicates were reused; no add-on or runtime framework was added. Original192 remains available for rebuilding and Git rollback; original043 remains the runtime owner’s retained rollback. The new resource has the same encoded size, mesh/collider count and native corner counts, with no added runtime geometry work.


## Distant terrain and stream

After the existing soil and flower owners, startup loads three pinned ArrayMesh
resources (49,715 encoded bytes). Two coarse opaque soil meshes meet 202 exact
native render boundary points and extend beyond the recovery bounds. They reuse
the original soil material, receive existing lighting and do not cast added
shadows. The existing stream node receives a mesh with 528 additional triangles;
all 13 original native channel/index prefixes, its material, transform and audio
identity are preserved. Its culling margin covers the shader's bounded 20mm wave.
Original water pointers and margins remain available for rollback. No collider or
playable bound changes; the existing player recovery remains authoritative.

This adds two draw nodes and 3,216 triangles overall, no new textures, shaders or
custom per-frame loop. Loading and native-channel verification are linear in the
bytes examined. The author runs offline: boundary scanning is O(V(X+Z)) in the
worst case because it deduplicates axis samples with small array lookups; grid
construction is O(XZ), indexing/compaction O(I), and sorting O(X log X + Z log Z).
V is source vertices, X/Z are axis samples, and I is generated indices. Temporary
storage is O(XZ + I + W), with W the retained water channels. This bounded authoring
work does not run during ordinary startup. Encoded size and triangle counts are
not GPU-memory measurements. The fresh complete-scene benchmark passes, but it
does not isolate the extra terrain/water fragment cost or establish a speedup.

## Forest layers and camera margin

The existing native forest constructor keeps seed 530052 and the same 450
instances/208,920 triangles, grouped into 8 m MultiMesh chunks. Height groups
(12 low, seven medium, 11 tall) change transforms rather than assets. Root
positions remain anchored; one former river root moves to the east bank. Trees 6,
7 and 8 use the existing tall form to clear sampled views of the distant home;
Tree 6’s existing five collision shapes use the same new stem geometry. Native
meshes and shared foliage wind materials are reused. There are 55 draw nodes,
previously 56. The existing shadow-off policy for this supplementary layer is
retained; this does not qualify near-player tree shadow/contact quality.

Four reachable main stems gain five static CylinderShape3D segments each. They
follow the visible segment pose without nonuniform physics scaling. The circular
cylinder conservatively encloses the octagonal taper with at most a 7.52 cm shell;
branches/crowns remain visual. Existing unsafe-support metadata blocks Float and
safe-save support. Native broad-phase/query work depends on scene contents; no
per-leaf body or script simulation is added. Construction uses expected
O(T + I + S) work and O(T + I + S) temporary/retained state for T trees, I placed
instances and S cylinder shapes; those counts are fixed here at 30, 450 and 20.
No forest geometry construction runs per frame. Foliage pixel coverage and shadow
cost elsewhere still require the complete-scene measurement.

The pinned Godot shape-based SpringArm implementation omits its margin subtraction.
The inherited sphere cast stays in use; a single child carrier places the existing
Camera3D 5 cm inward. Native transform propagation supplies this constant offset,
with O(1) added scene state and no extra custom per-frame cast or solver. Maximum
ordinary camera distance becomes 3.75 m; manual comfort and full-frustum clearance
remain separate from sampled sphere/ray tests. Git `843886c` is the complete prior
layout/camera/collider rollback; `build(world, true)` supplies the unchanged visual
reference layout only for paired verification, not an independent gameplay mode.

`reports/.gdignore` prevents test screenshots from becoming imported game textures.
Only that sentinel is tracked under reports; generated results remain ignored.
Removing its regenerable image cache does not change runtime texture quality or
establish a memory/frame-time improvement.
