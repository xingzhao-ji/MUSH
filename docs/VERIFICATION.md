# Verification of the clean source

October 11, 2026. The portable development copy imports and passes its fresh gameplay, environment, material-parity and still-capture checks. **The current mac063 app fails p95; the current source passes its recorded route. Earlier results remain recorded.** The as-is GitHub baseline upload is verified; whole-game release acceptance remains open. Each result is bound to its recorded source fingerprint; later source changes require the relevant checks again.

The checks use Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), Forward+/Metal, an Apple M4 Pro Mac with 48 GiB RAM, and Dummy audio. Engine SHA256: `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

## Initial clean-repository checks (historical)

| Check | Result | Scope |
| --- | --- | --- |
| Clean import | Passed | One generated test UID was recorded; no imported engine/cache files belong in Git. |
| Gameplay acceptance | **295/295 assertions, 15/15 scenarios** | Real Main startup, physics, gameplay and save/crash-recovery tests; automated input, not manual controls. |
| Ground material parity | **32/32 checks and 14,867 native comparisons**, before and after cleanup | Live startup, six appearance/lifecycle phases, material/texture aliases, repeated refresh and 32-entry capacity. |
| Environment contract | **133/133 checks** | The stale SSR expectation was corrected to the retained production setting, disabled. This does not enable SSR or prove mobile rendering performance. |
| Fresh local Git clone | **Import and 12/12 headless smoke checks passed** | Commit `8a38520`, 242 tracked files, source manifest validated, no source changes; this is portability/startup evidence, not GPU or remote-clone acceptance. The temporary clone was removed. |
| Still captures | **4/4 images**, 960 × 960, full PNG decode/CRC and pixel/hash readback | Day, night and entrance views. The receipt distinguishes paused World motion from continuing environmental shader motion. Art and motion remain unaccepted. |

Successful suites recorded no source changes during execution; import separately admitted its new UID. The runner rejects optimized Python execution that disables assertions, checks benchmark route completion/resolution, and keeps evidence in ignored `reports/`. Four runner tests also pass: failed native execution, failed assertions, source mutation and compression failure still leave an honest receipt. Preservation is now checked even after a failed suite. Full reports remain local; the compact [verification summary](verification-summary.json) records their hashes and paths.

## Frame-time gate

The unchanged limits are **p95 <= 16.7 ms** and **p99 <= 33.3 ms**. All three 120-second night/rain routes completed two loops with zero stalls at 1920 × 1080 output. Every run exceeded p95; their failures remain failed.

| Run | Timing condition | Frames | p95 | p99 | Result |
| --- | --- | ---: | ---: | ---: | --- |
| 03:07 | Default VSync | 7,133 | 18.768 ms | 21.097 ms | Failed p95 |
| 03:12 | Uncapped diagnostic | 9,285 | 17.903 ms | 20.770 ms | Failed p95 |
| 03:15 | Matched window, default VSync | 6,808 | 23.716 ms | 27.853 ms | Failed p95 |

Percentiles were independently recomputed from each complete CSV. These measure application callback intervals, not display presentation. The Godot GPU timing monitor is unavailable. Source/render settings and window conditions are in each receipt; the rows are not a controlled before/after speedup comparison. The historical249 pass does not override these fresh failures.

Short 30-second script/native profiling runs are diagnostics only, include instrumentation overhead and completed no route loop. Later script-profiler samples are mostly around 1 ms, with startup spikes separately present. That suggests script micro-optimization alone is unlikely to explain the whole interval, but it does not identify or measure a GPU bottleneck. Native sampling reported a roughly 1.9 GB physical footprint; the engine's roughly 140 MB static-memory monitor is a different metric. Per-presented-frame GPU/display timing and sustained thermal behavior remain unmeasured.

A separate **20.984-second Metal System Trace** reported Godot-attributed **Active GPU intervals covering 96.28%** of its window, with nominal thermal state. Queue latency was verified separately against 40,011 matched events. This is active-interval coverage, not hardware occupancy/utilization or a sustained pass. CPU encoding intervals cover 26.55%; no presented-handler records or semantic render-pass labels were available. The trace supports substantial GPU-side work, but identifies no proven redundant draw/pass that can safely be removed. It is not a reason to lower visual quality or the existing limit.

A subsequent isolated shader trial added a uniform early return when cloud-shadow strength is exactly zero at night. It preserved the finite scene expression but still failed the same 120-second budget: **p95 18.855 ms, p99 21.159 ms**, two loops and no stalls. No useful improvement was established; the trial was **not adopted**. Its patch/CSV/receipts are retained locally, and its disposable source clone was removed after hash checks.

The material-forwarding change removes a temporary O(V) values array, with V <= 32, while preserving O(VU) forwarding work. Native parity passes. **No measured frame-rate improvement is claimed.** Further performance work must preserve scenery and use fresh measurements.

## Storage verification

Authorized archive cleanup removed 25 redundant extracted apps only after validating retained ZIP payloads. All archives, accepted apps, source generations, unique assets and saves remain available.

842 large JSON reports were losslessly filesystem-compressed. All 842 logical payload SHA256 hashes were independently reread successfully; allocated report bytes fell by **8,447,594,496 bytes**. Available space was **10,547,183,616 bytes before** and **18,721,767,424 bytes at the later recorded sample**: approximately 10.547 → 18.722 GB, or 9.82 → 17.44 GiB. This observed free-space difference is not exact exclusive attribution because APFS sharing, delayed accounting and other activity affect it.

The unchanged post-cleanup guard passed 628 strict records and verified all 230 original243 source payloads. The protected metadata audit recorded ten ctime-only changes outside cleanup targets with unproved cause; contents were subsequently verified, and historical metadata equivalence is not claimed. A final strict guard later stopped on an iCloud-offloaded UID file. An independent final readback matched **all 628 strict payload hashes**; two ordinary hydration reads changed ctime. That metadata gate remains failed and was not weakened. This is distinct from the immediate post-cleanup pass. The clean repository's measured Git pack is **36,685 KiB / 35.83 MiB**; this excludes ignored caches/builds/reports and is not game memory usage or a remote-upload measurement.

## Open acceptance

Physical iPhone/iPad/Android tests, an installable IPA, live listening, sustained manual movement/camera comfort, continuous real-time motion quality and final art/reference fidelity remain pending. Near-cut paving contact coverage, the aggregate full-route contact gate, thick dark slab fronts, broad moss gaps, night readability, shadow/contact quality and water joins remain open. The character remains provisional.

Local receipts are under `reports/`; archive cleanup receipts are under the retained `mobile-transition/review/storage-cleanup253/` archive. `SOURCE_MANIFEST.json` binds the portable tracked payload (excluding itself). Local Git commits retain the baseline and the narrow allocation change for rollback; remote baseline `08c4187` was independently cloned, all 242 files matched, and import plus 12 headless startup checks passed.

## Entrance stone surface successor

The Rock01 top material was isolated before integration, then tested again through
actual startup. Both runs pass 19 native checks and eight fully decoded paired
960-square PNGs (day, night, rain and wider daylight). Mesh channels, registered
collision shape/RID, other material aliases and frozen pair context stay exact.
Both comparison materials receive live environmental updates; restoring the actual
installed material pointer revalidates the paving owner. An initial fixture-only
Dictionary type-inference error is retained as a failed run, then corrected.

Fresh integrated gameplay passes **295 assertions / 15 scenarios**. The integrated
120-second night/rain route completes two loops without stalls at 1920 x 1080:
**p95 18.476 ms, p99 19.446 ms, 7,172 frames**. The unchanged 16.7 ms p95 gate
still fails. These are callback intervals, not presented-frame/GPU measurements;
no speedup or zero-cost claim follows from comparison with earlier runs.

Source JPEG: 688,083 bytes. Imported cache: about 1.97 MB. Native RGB image plus
10 mip levels: 4,194,303 bytes (CPU readback, not GPU residency). The existing
shader adds one planar sample and albedo-derived shading relief; vertices,
collision, draw-node count and gameplay physics are unchanged. The weathered
surface improves the smooth manufactured appearance, while thick dark fronts,
wide gaps, night readability and reference fidelity remain open.

## Packaged Mac successor

The separate mac061 development app is exported with a new save directory and
verified ad-hoc signature. Corrected normal bundle launch passes 12 exported
startup/effects checks; the previously excluded capture hook now produces all
four decoded PNGs. Native UI observation covers new game, glow, pause, night/rain
selection, Save & quit, relaunch and Continue restoring the saved appearance.
Both ordinary sessions exit 0; prior profiles and source remain unchanged.

Its independent 120-second night/rain benchmark completes two loops without stalls:
7,173 frames, **p95 18.522 ms / p99 19.447 ms**, still failing p95. A 3.53-second
1280 x 720 offline30-FPS smoke clip is also retained and fully decoded. Offline
video does not measure real-time motion/pacing. Live audio and sustained control
feel remain open. See [launch instructions and artifact limits](MAC-CANDIDATE.md).

## Lower entrance joint successor

Only the two lower stones and their shared soil/contact vertices changed. At
three measured sections the center joint is now 39.10–40.02 mm, previously
99.10–100.02 mm. The upper stones and 52-triangle upper soil roof remain exact.
The native authoring check passes 45 checks for channels, winding, seams,
bounds, slopes, closed stones and saved-resource readback. Render/contact caps
retain their original different triangulations; their directed boundaries and
planar domains coincide, with a measured maximum separation bound below
0.00000012 m.

The first lower-row trial passed static geometry checks but stalled on a real
diagonal ascent. It moved one outer shoulder by 5.77 mm, changing a steep
shared-soil ridge. The adopted version holds those two approach triangles exact
and passes all 58 movement routes without changing the controller, arrival
limits or safety gates. Failed trials remain in the local reports.

Both isolated and installed runs pass every movement route and contact profile.
The full traversal suite **still fails** its separate moving upper-roof/near-cut
contact gate: neither run records a qualifying roof contact. Native ownership,
registered shape, settings and restoration pass. These are automated physical
routes, not manual control-feel acceptance. Eight paired day/night/rain/wider
PNGs pass full decoding and show the narrower lower joint; thick slab fronts,
the upper gap and night readability remain unfinished.

The successor is 641,570 bytes, exactly the previous artifact's encoded size.
It retains 17,217 render corners, 7,323 contact corners, three existing mesh
nodes and one registered collision shape. No geometry generation runs at
startup or per frame. Keeping the original192 resource/proof and the new
9,420-byte manifest adds 650,990 bytes to the source checkout. No steady-state
memory or frame-time improvement follows from those counts.

Rollback: Git checkpoint `65f7168` restores the prior192 startup and material
state. The original192 artifact and proof are still byte-exact in `baked/`.
The existing runtime owner's rollback continues to restore its original043
resources; it does not switch to192. `shape-build` rebuilds the isolated
candidate from192; native geometry is checked independently of Godot's assigned
resource UID. `shape-capture --candidate PATH` compares that candidate with
the currently installed source. The compact manifest retains the still-false
full-contact, art, sustained-performance and physical-device acceptance flags.

Fresh integrated gameplay passes **295/295 assertions across 15 scenarios**.
The later 120-second night/rain source benchmark passes the unchanged
16.7/33.3 ms p95/p99 gates: **p95 16.414 ms, p99 19.119 ms, 10,096 frames**,
two route loops, zero stalls, 1920 x 1080, default VSync. Both percentiles were
independently recomputed from the full CSV. This single route pass does not
establish a causal speedup over earlier failed runs, presented-frame timing,
GPU cost, sustained thermal behavior or mobile performance. The baked manifest's
false acceptance flags retain its experimental release scope; measured results
collected after baking are recorded separately here.

The candidate swap path was also rerun against the newly installed successor:
58 movement routes pass, native pointers restore exactly, and the same
upper-roof contact gate remains failed. Source preservation passes in these
isolated/installed/rollback runs. The earlier baseline run's source-membership
guard failed when a new helper appeared during execution; it remains failed
evidence and is not a closed preservation pass. The current mac061 app contains
the earlier surface checkpoint; this geometry successor is tested in source.

## Restrained moonlit sky bounce

The central environment controller now sets the existing sky fill to .05 in
daylight and .30 at night (previous night value .18), retaining its cool tint,
opposed direction, shadow policy and linear appearance blend. This inexpensive
approximation adds no light, shadow map, geometry, texture or simulation. Its two
extra native property assignments are constant work/state; incremental GPU cost
has not been isolated. Warm practical lights illuminate nearby objects; existing
gill/plant material emission is visual glow, with separate cool point lights
providing nearby illumination. No emission or bloom setting changed here.

Two isolated energy comparisons preceded integration. Stronger .55 fill flattened
the clearing, while a broader ambient increase softened contrast; neither was
adopted. The chosen .30 fill gives a subtle lift to shadowed path edges. Five
integrated before/after camera pairs cover entrance, clearing, water, interior and
night/rain. All ten PNGs fully decode and match native hashes. Material bindings,
paving arrays and registered contact remain exact within each pair; the fixture
does not hash every world mesh or establish motion quality. The provisional
interior, thick slab fronts, water joins and overall reference fidelity remain open.

Four new paused quality/day-night assertions first failed only the two night
endpoints (.18 observed), then passed after integration: **137/137 environment
checks**. Fresh actual-Main gameplay passes **295 assertions / 15 scenarios**.
Local evidence: `reports/night-lighting-trial-20261011/`,
`reports/environment-20261011-061404-25715/` (expected red),
`reports/environment-20261011-061452-25791/` (green), and
`reports/acceptance-20261011-061736-25977/`. Prior performance results qualify their
recorded source, not this lighting successor; its new Mac package is checked separately.

To make export room, 59 generated import/shader/export cache subfolders in 28
inactive archived development copies were removed: **414,265,344 allocated bytes**
selected. Editor state, current/accepted055/057 caches, source, assets, apps, saves
and references were retained. Project-file hashes match before/after. APFS free
space rose later; the instantaneous free-space delta is not exact attribution.
A separate attempted transparent compression of profiling evidence saved no
space; no replacement was adopted. Receipts: `reports/cache-cleanup-20261011-0620/`.

## mac062 exported successor

The isolated fresh-profile package contains the lower joint and restrained night
fill. Source/ZIP/app checks, ad-hoc signature, 12 exported startup/effects checks,
four fully decoded PNG captures and a 3.53-second offline in-engine clip pass.
The export stage was removed; prior profile metadata and app/source payloads
remain exact. The package helper now accepts an unused `macNNN` profile/bundle
name, excludes that candidate from prior-profile guards and discovers other
existing candidate profiles. Invalid path-like names are rejected before output
creation; candidate-self exclusion and prior-candidate coverage were checked.

Its 120-second 1920 x 1080 default-VSync night/rain route completes two loops with
zero stalls: **9,438 frames, p95 19.521 ms, p99 28.327 ms**. Complete CSV validation
and percentile recomputation pass, but the **16.7 ms p95 gate fails**, so the
combined exported verification receipt is failed. This does not establish that
the two lighting property assignments caused the difference from older runs.
GPU timing is unavailable; display presentation, live audio, sustained manual
controls and physical phones remain unverified. See [launch instructions](MAC-CANDIDATE.md).

## Narrow-joint step support

The actual player could remain grounded but stop against an upper stone when
walking through the center joint. A repeated native diagnostic held the exact
pose for 247 input ticks: the center proposal ray hit an 87.35-degree inner
return, while rays 14 cm to either side reached walkable stone tops. A slightly
different approach instead hit low soil at the center and proposed too little
lift. Full-capsule clearance correctly refused that route.

The existing tagged-step controller now considers both lateral supports at
starting, proposed and landing support checks. Both must be walkable, within
the tagged bounds, on the same body/shape and within 20 mm in height. A higher
pair may replace a lower center hit only on that same body/shape. Native
up/ahead/down capsule sweeps, every landing contact, the 20 cm rise limit,
clearance and cancellation rules still decide movement. General hover/safe-save
support queries are unchanged. Meshes, registered collider and materials are
held exact. This reuses Godot physics and adds at most two ray requests per
step-support lookup with constant script state; native query cost depends on
the collision world. Incremental CPU cost was not isolated. No asset/dependency
or per-frame simulation system was added.

The four-route regression fails on the original controller and passes with the
fix: slow/full ascent and descent, two completed steps, no aborts, maximum
measured step rise 0.17847 m. The integrated suite passes 19 checks plus all
16 fixture checks across ten native support cases, including missing sides,
different bodies/shapes, excessive side-height difference and preserved center
identity. Shared setup was extracted from the existing traversal fixture; its
original arrival limits and full contact gate are unchanged.

Fresh original traversal passes all 58 movement routes, with 7,377 callbacks.
It still fails exactly one of 165 checks: moving upper-roof/near-cut support.
The separate diagnostic reaches the back of that region but the capsule rests
on the next step edge, 116 mm above the center soil. The earlier 82 mm endpoint
clearance failure and a small steep soil edge remain recorded. Paired stepping
is not roof-contact evidence or a repair to those visual/geometry issues.

Fresh broader gameplay passes 295 assertions across 15 scenarios. The source
120-second night/rain benchmark passes unchanged 16.7/33.3 ms limits:
**p95 16.389 ms / p99 18.439 ms**, 10,012 frames, two loops and no stalls,
1920 × 1080, default VSync. Percentiles are recomputed from the CSV. This is
one source callback-timing result, not a causal speedup, GPU/presentation,
thermal or physical-mobile result. The frozen mac062 app retains its own failed
p95 measurement and does not yet contain this controller fix.

`reports/gap-step-motion-20261011/paving-gap-walk.mp4` retains 275 decoded frames
at 1280 × 720 and 30 FPS (9.1667 seconds). The same regression and native
fixtures pass during capture. Four extracted frames were inspected; continuous
motion quality and real-time/manual control feel remain unverified. The fully
decoded MP4 is 11,470,564 bytes; its 42,573,204-byte temporary AVI was removed.
Source preservation passes for the successful suites and the retained failed
baseline/coverage runs. No device or live-audio acceptance is claimed.

Rollback: checkpoint `9502353` restores the prior controller/test source. The
unchanged mac062, accepted 0.5.7 and 0.5.5 rollback apps remain available. An
unused roof-triangulation experiment stays under ignored reports and was not
integrated. Thick upper fronts, upper gap, soil-contact coverage and whole-game
art acceptance remain open. Exact receipts/hashes are in the compact summary.


## Upper entrance joint successor

The upper center seam now measures 41.61–42.05 mm at three declared sections,
previously 131.61–132.05 mm. These are trial dimensions guided by the approved
reference's narrow moss joints, not measurements extracted from the image.
Top planes, outer shoulders and front tips are retained. Shared soil/contact
boundaries move with the stones. Three of the 52 soil faces are retriangulated
through native Geometry2D; render and contact coordinates match exactly.

The final artifact passes 49 native authoring checks, including closed boundaries,
no overlap/crossing, slope restrictions, unchanged steep-area coverage and saved
resource readback. It retains the same 641,570 encoded bytes, three meshes, one
collision shape and triangle counts. It replaces the lower-only successor rather
than accumulating another runtime resource. Original192 remains; Git `bff9467`
restores the prior lower-only source. Existing runtime rollback still restores043.
The seven reused scalar geometry predicates and native Geometry2D avoid a new
triangulation dependency. Quadratic triangle/edge proof checks are offline and
bounded by this small patch; no new per-frame work is introduced.

The first narrowed variant exceeded the existing 18-tick unsupported limit.
Preserving both front tips reduces the slow ascent to 15 ticks. A separate
fixture issue then appeared: its braking model omitted a 0.316 mm native sideways
correction and stopped on an 87.35-degree inner return. The unchanged target is
safe. Arrival now requires safe current/predicted poses, observes the same 20
settling ticks, and allows at most three ordinary-input refinements toward that
same target. Every callback and failed stop remains recorded; original final
arrival, grounding, clearance, unsupported-time and contact gates are unchanged.
The global budget is checked before input and again after settling. The player
controller, hover and safe-save support code are unchanged by this successor.

The final gap suite passes 20 checks/four routes and all ten native support cases:
523 callbacks, two completed steps, zero aborts, maximum rise 0.17417 m. Its slow
approach crosses within 4.01 mm of the historical snag and needs one small arrival
refinement. The final full suite passes all 58 movement routes and exact native
owner/settings/rollback checks, with 7,352 callbacks and no arrival retries.
**One of 169 checks still fails: moving upper-soil/near-cut contact coverage.**
No still image, ray probe or successful stone crossing substitutes for that gate.

Fresh gameplay passes 295 assertions across 15 scenarios. The source benchmark
passes the unchanged 16.7/33.3 ms limits: 120-second night/rain route, 10,091 frames,
p95 16.302 ms / p99 18.321 ms, two loops, no stalls, 1920 x 1080, default VSync.
These are callback intervals, not GPU/presentation, thermal or mobile measurements,
and do not establish a causal speedup over prior source.

Eight matched PNGs fully decode. In the final comparison, `*-before.png` depicts
the installed upper-joint successor and `*-after.png` depicts the retained
lower-only baseline loaded for comparison. The four installed day/night/rain/wide
views and baseline daylight view were inspected against the approved reference.
The joint is visibly narrower; thick block-like fronts, dark night paving,
provisional foliage/character art and overall reference fidelity remain open.
Still captures do not qualify motion or live listening.

Three redundant extracted apps (mac061, mac058, mac059) were removed only after
all seven files per app matched retained ZIPs and receipts. Selected allocated
bytes: 1,166,565,376; observed free-space rise: 1,166,381,056 bytes. Current mac062,
accepted057/rollback055, ZIPs, evidence and profile siblings remain. A guarded
restore helper is retained with the cleanup receipt; inode/ctime/birthtime cannot
be reconstructed. Source receipts and exact hashes are in the compact summary.


## mac063 exported checkpoint

The separately exported mac063 app includes both narrowed joints and the paired
step-support fix. Packaging, exact source/ZIP/app checks, ad-hoc signature and
12 exported startup/effects checks pass. Four exported captures fully decode.
The 120-second night/rain app route records 9,678 frames, two loops and no stalls,
1920 x 1080 with default VSync: **p95 18.049 ms / p99 23.515 ms**. The p95 gate
still fails; the combined exported verification receipt remains failed.

The offline capture contains 106 decoded 1280 x 720 frames at 30 FPS (3.533 seconds),
plus a decoded AAC track. The 3,343,295-byte MP4 is retained; its temporary AVI was
removed after encoding/count/complete decode checks. This is not real-time pacing
or listening evidence. Prior profiles, ordinary candidate save slot, source and
app/ZIP payloads/metadata remain exact during these automated runs.

A separate ordinary app launch reached CLEARING_READY, but the native UI tool
could not locate its window (cgWindowNotFound). The owned process was terminated
and reaped, and the failed attempt retained. No ordinary save was created;
Save/Continue and visible ordinary UI remain unverified on mac063. mac061's prior
UI evidence is not transferred to this app. Current launch/artifact details are
in MAC-CANDIDATE.md. The user-authorized upload retains these unmet gates.

## Front paving surface successor

The existing pinned CC0 Rock01 texture now also covers the front paving batch,
using the existing shader's world-space triplanar branch. This makes weathered
front faces read more consistently with the tops. It affects all 3,078 batch
corners, including the retained 2,598-corner prefix. Relative to the previous
source, it adds one startup material and three albedo samples on visible front
fragments. It adds no texture file, draw node, geometry, collider or custom frame
loop; the existing environment loop receives the additional material binding.
The albedo-derived relief is shading only. GPU sampling cost is not isolated.

Isolated and integrated front comparisons each pass 19 checks and eight full
PNG decodes. The refactored top comparison also passes 19 checks/eight decodes.
All native geometry/contact, nonselected aliases and original art uniforms remain
exact, and the actual installed material pointer is restored after comparisons.
Both materials receive live clock/cloud/wetness values. Source import passes;
the four Python runner failure-path tests pass. The consumer additionally binds
selected batch, projection mode and fixture hash to the requested suite.

After those material runs, startup report fields were clarified to distinguish
pre-install corner counts (972/2526) from final geometry counts (4638/3078), and
to describe the existing environment binding. The consumer reread both material
receipts successfully. Fresh gameplay on the clarified source passes all 295
assertions across 15 scenarios. Its 120-second night/rain route passes with
10,189 frames, two loops, no stalls, 1920 x 1080 and default VSync: **p95 16.254 ms /
p99 17.853 ms**. These are callback intervals, not presented frames or GPU timing.
The run establishes no causal speedup, sustained thermal or mobile result.

The separate upper-front geometry trial is **not adopted**. The last trial passed
58 native checks, matching render/contact and exact soil/base preservation, but
paired art review found only a marginal lip change. Earlier slope/inversion
failures remain failed. Its movement was deliberately not qualified. Current
baked geometry remains `1cc176e9f0f195b50927c2e3526e5ac892b4eb047d6218ecb7a71fe0e8001057`.
Thick front silhouettes, night readability, reference fidelity and full upper-soil
contact coverage remain open. Still images do not qualify motion or live audio.

The frozen mac063 app/ZIP predates this material change. No new package or app
performance result is claimed. A second ordinary mac063 window attempt used an
explicit on-screen position and a fresh UI-tool session; cgWindowNotFound persisted.
Its failed receipt and exact source/profile/app guards remain recorded, and the
owned process was reaped. No ordinary mac063 save/Continue proof was obtained.


## Leafier ground-flower successor

Ordinary startup now replaces only the byte-exact stock flower MultiMesh mesh
with a pinned offline asset. It has a shorter curved stem, smaller upward-facing
petals and three attached leaves. All 119 nodes/1,430 placements, their instance
buffers, materials and shadow settings remain. Separate bouquets, vines and
understory geometry are untouched. Original mesh pointers remain available;
Git `8fb95d3` restores the preceding source. Artifact SHA is
`d16b4985a881a5dc8e9ede662702514e3c1f5add6a9828f076031f06b48ffb5e`.

The mesh remains 94 triangles/282 corners, with six exact root-plane corners and
bounds inside the original envelope. Height falls from .36m to .281m before the
existing instance scales. The resource is 9,613 bytes. It adds no texture, draw
node, material variant, collider or custom per-frame loop. Startup loads one mesh
and compares known native geometry during the existing node scan; temporary work
is bounded by node count and the fixed 282-corner template. One additional cached
wind descriptor is retained alongside the unchanged five constructor proofs.
Existing GPU animation supplies the same wind direction, anchored base and culling
margin. These counts are not measurements of GPU residency or fragment cost.

The isolated corrected comparison passes 12 checks/eight full PNG decodes.
Final ordinary-startup verification passes 23 checks/eight decodes, including
fresh admission of every flower, actual pointer rollback/reinstall, unrelated
native geometry/collider preservation and frozen material/context comparisons.
All 38,610 unique leaf-corner samples across the 1,430 rendered placements find
native layer1 ground: zero penetrations beyond the unchanged 5mm tolerance,
minimum clearance 3.085mm. Twenty-seven hits on the identified overhead bridge
are recorded and re-queried with that architectural body excluded. This proves
sampled ground clearance, not complete blades, rocks or wind-deformed surfaces.
It does not move the inherited flower underneath the bridge.

Early attempts remain failed: downward-facing petals were corrected, and low
leaves intersecting sloped ground were raised to real stem attachment points.
Typed-array fixture errors were corrected. A headless placement diagnostic was
discarded: a focused witness measured identity transforms for two distinct
MultiMesh instances, while a direct ray at the rendered witness still found the
same terrain. The final test requires rendered native placement diversity and
full instance buffers. Rebuilding produces identical native channels/metadata;
Godot's generated local resource ID varies, so byte-identical containers are not
claimed. The adopted file itself remains hash-pinned.

Fresh broader results: 137 environment checks, 32 material checks/14,867 native
comparisons, 295 gameplay assertions/15 scenarios, and four Python runner tests
pass. The 120-second night/rain source route passes unchanged limits: 10,181
frames, two loops, no stalls, 1920 x 1080, default VSync; p95 16.114ms / p99
18.069ms. These are application callback intervals, not presented-frame/GPU,
thermal or physical-device results, and establish no causal speedup. Runtime code
was unchanged after that route; a final fixture-only correction derives its wind
status from the actual admission gate, and its fresh 23-check run passes.

The source smoke recording has 106 decoded 1280 x 720 frames at 30 FPS, 3.533s,
and a fully decoded AAC track. The 4,004,352-byte MP4 is retained; its 14,108,892-byte
working AVI was removed after complete verification. It is offline smoke footage,
including the ordinary camera after pause/resume, not continuous motion/listening
acceptance. About 12.8 GiB remains free. No new app was exported: mac063 stays frozen
with its earlier p95 failure. Exact receipt paths and hashes are in the summary.

| Flower scope | Status |
| --- | --- |
| Shape, stock-instance preservation, startup wind admission | Implemented and native-tested; local shape direction reviewed in day/night/rain views |
| Sampled ground clearance and rollback | Tested as described above; no collision geometry changed |
| Dense, varied planting matching the reference | Still unfinished; sparse grouping and coarse neighboring leaves remain |
| Full animated clearance, continuous motion and mobile cost | Unverified; no physical device available |


## Terrain-edge and stream successor

The previous terrain stopped before several perimeter trees. Two prebuilt opaque
soil meshes now cover that exposed edge, using the existing material; the same
stream node continues north through a shallow distant valley. Paired day, night,
rain, side and reverse views show ground behind the roots and a connected water
surface. Bare hills and repeated tall trunks remain unfinished scenery. This is
an extension of the visual background, with no new playable terrain or physics.
The source before this change is Git `2a9b6f6`; retained mesh pointers also provide
runtime rollback. No add-on, new texture or shader was introduced.

The three compressed meshes total 49,715 bytes. Added geometry is 2,688 soil and
528 water triangles, with two additional draw nodes. The native build/save/load
check passes all channels, winding, finite values, valid indices and zero unused
vertices. All 13 original stream array/index prefixes are exact. Its original
material, transform and unique audio alias remain; a 20mm culling margin covers
both bounded wave terms. Startup loads/verifies assets, with no new custom frame
loop. Additional render cost is included in the scene benchmark, not isolated.

Final rendered verification passes 19 checks and ten complete 1280 x 720 PNG
decodes. All 202 original soil render seams are exact. The original colliders have
inherited coordinate rounding: maximum matched difference is 0.0706mm, below the
unchanged 0.1mm correspondence limit. No old body or playable boundary changed.
Eight actual player perimeter positions at three camera pitches each pass native
camera checks. All 24 actual 0.14m camera-sphere poses, including five over the
added soil, return no intersection with exact query-only terrain triangles at
1mm margin. That test geometry is removed afterward. These samples do not prove
every possible camera path.

Fresh broader checks pass: 137 environmental assertions, 295 gameplay assertions
across 15 scenarios, and four Python runner tests. The 120-second night/rain route
records 10,127 frames, two loops and no stalls at 1920 x 1080/default VSync:
**p95 16.130ms / p99 18.029ms**, within the unchanged 16.7/33.3ms limits.
These are callback intervals, not presented-frame/GPU, thermal or physical-device
measurements. No runtime code changed after the benchmark. Earlier rejected
white-wedge geometry, collision-coordinate assumptions, water-edge selection and
fixture parser attempts remain recorded as failures.

The source smoke clip fully decodes 106 frames at 30 FPS (3.533s), 1280 x 720, plus
AAC audio. The retained MP4 is 4,139,652 bytes. Its 14,101,842-byte working AVI was
removed only after full decode and exact source/stat/hash checks. The clip starts
from a gusty side view; pause/resume restores the ordinary camera. This offline
recording does not qualify real-time motion or live listening. About 12.1 GiB
remains free. No app was exported: mac063 remains frozen before this change and
retains its recorded p95 failure. Exact receipt hashes are in the compact summary.

| Terrain scope | Status |
| --- | --- |
| Exposed-edge coverage and stream continuity | Implemented; inspected in ten paired day/night/rain images |
| Native seams, geometry, original physics and water alias | Tested; original pointers retained for rollback |
| Sampled perimeter camera and broad gameplay | Tested at 24 sphere poses and 15 gameplay scenarios |
| Layered forest art and full reference fidelity | Still unfinished |
| Continuous motion, live audio, current export and devices | Pending; no physical device connected |


## Mixed-height forest and trunk/camera contact

The existing 30-tree layer now uses 13 low, nine medium and eight tall trees.
Native meshes, materials and RNG draw order are retained; 450 placed instances
and 208,920 triangles are unchanged. Spatial batches fall from 56 to 55. Moving
one seeded root onto the east bank clears its previous water placement. The
reviewed paired views give the home more foliage at middle height; entrance and
bridge readability remain. The side view still forms a regular foliage band,
some background windows are more obscured, and reference fidelity is unfinished.

Four previously pass-through reachable stems now use 20 static native cylinder
shapes. Their transforms and dimensions match the rendered main-stem segments;
the conservative shell extends at most 6.27 cm beyond the tapered octagonal
surface. Branches, crowns and distant stems remain visual. Existing unsafe-support
metadata prevents these caps from becoming Float support or saved recovery sites.
No gameplay force or paving-step tag was added. Git `843886c` restores the prior
layout, collider and camera state; the reference constructor also reproduces the
preceding native chunk-buffer fingerprint for matched images.

An isolated contact test exposed three camera intersections among 36 poses.
The exact [pinned Godot SpringArm implementation](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/scene/3d/physics/spring_arm_3d.cpp)
applies its configured margin in the ray branch but not the explicit-shape branch.
A native carrier now offsets the same Camera3D inward by 5 cm, retaining the
sphere cast and existing fade/controls. This makes the unobstructed lens distance
3.75 m instead of 3.80 m. It adds one Node3D and no custom per-frame query or solver.
The corrected isolated and integrated camera checks pass. Saturated overlap
queries are refused; the fresh twelve trunk-pose queries each returned zero hits.

The final integrated `forest-layers` run passes 28 checks, 19 contact assertions
and ten fully decoded 1280 x 720 paired PNGs. Ground checks cover 246,750 unique
placed leaf corners: 117,859 exceed the terrain's global maximum; 128,891 are
ray-tested, of which 2,904 lie in the authored river gap above the nominal water
height. There are no unexpected misses or soil penetrations; minimum sampled
soil clearance is 17.42 cm. All 30 root bases meet the soil. Finite transforms,
native bounds and a conservative analytic wind/culling bound pass. This is not
GPU-deformed surface readback or proof of water beneath every channel sample.
The distant negative-Z channel beyond the original water end remains unverified.

Actual CharacterBody traversal supplies 684 approach/slide/retreat physics ticks
across all four stems. Every tick checks the actual capsule for penetration;
native obstruction/deflection, safe retreat, no unwanted step, support refusal
and restored endpoint/settings all pass. Camera checks cover 24 existing
perimeter poses and 12 trunk approaches; all four new trunks shorten the native
spring arm when expected. These sampled routes do not cover every hover, camera
or full-frustum path. Earlier low-crown penetration, submerged-root, fixture
lifetime and camera-overlap failures remain preserved as failed evidence.

## Prevent repeated screenshot imports

`reports/.gdignore` now keeps verification images out of Godot's asset importer.
It is the only tracked file under that directory. The targeted cleanup fully
decoded 227 original PNGs, then removed 454 matching generated texture/cache files
with 244,547,584 allocated bytes (233.22 MiB). Original images, import settings,
source, game textures, shaders and other caches were preserved and checked.
Observed free space increased by 243,798,016 bytes; this is not exclusive APFS
attribution. Godot can regenerate those textures from the retained images in a
nonignored directory. The first RGB8 decoder attempt failed before deletion;
the retained successor uses full ffmpeg decoding. The 10 GiB reserve still applies.

Fresh broader checks pass 137 environment assertions, 295 gameplay assertions
across 15 scenarios (including indoor/fast-turn camera tests), and four Python
runner tests. The current 120-second night/rain route records 10,025 frames,
two loops and zero stalls at 1920 x 1080/default VSync: **p95 16.259 ms / p99
17.788 ms**, within the unchanged 16.7/33.3 ms limits. CSV percentiles are recomputed
by the runner. Runtime source stays unchanged through these checks. This does not
isolate collider/foliage cost or establish a causal speedup, GPU/display,
thermal or physical-device performance. The environment run predates only the
final camera-test saturation guard; no runtime implementation changed afterward.

A new ordinary-camera in-engine recording reuses the four real contact routes
with the character animation and gust environment active. Its nine capture-owner
checks and 19 contact assertions pass. All 514 frames fully decode at 1280 x 720,
30 FPS (17.133 seconds). The retained silent MP4 is 24,437,874 bytes; its 64,711,348-
byte working AVI was removed after full decode and exact source/stat/hash checks.
The initial Vector2/Vector2i capture-fixture parser failure remains failed evidence.
Four sequential samples are retained at 3, 7, 11 and 15 seconds. These reveal a
distant mushroom house that looks unsupported from the east-tree route, plus a
close-tree view that obscures the character during the turn. The capture observer
checks node visibility/current-camera ownership, not pixel visibility: its pass
does not waive those visual defects. Continuous motion, real-time pacing and
live listening remain unverified. About 12 GiB remains free; no new app was
exported. mac063 predates these changes and retains its measured p95 failure.

| Current forest/contact scope | Status |
| --- | --- |
| Mixed tree heights, grounded roots and sampled leaf clearance | Implemented, reviewed in paired views and native-tested |
| Four stem colliders and unsafe-support behavior | Tested in 684 actual movement ticks; other branches/crowns remain visual |
| Fixed 5 cm camera inset | Tested at 36 static poses and broader gameplay locations; full path/frustum coverage remains open |
| Local frame-time route and report-cache cleanup | Measured as above; no mobile or isolated speedup claim |
| Foreground tree obstruction and distant-house foundation | Visible defects retained for the next correction |
| Full reference fidelity, shadows/contact, manual motion/audio | Still unfinished or unverified |
| Current export and physical-device testing | Pending; no device is connected |
