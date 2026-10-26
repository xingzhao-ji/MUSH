# Verification of the clean source

October 11, 2026. The portable development copy imports and passes its fresh gameplay, environment, material-parity and still-capture checks. **Current cream-tail source and the separate mac066 export pass their recorded callback budgets with engine draw progress. The older mac065 app fails p95, including an unchanged repeat; those failures remain recorded.** The as-is GitHub baseline upload is verified; whole-game release acceptance remains open. Each result is bound to its recorded source fingerprint; later source changes require the relevant checks again.

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

## Legacy outer-trunk contact correction

The recorded foreground obstruction came from an original noncollidable trunk,
not the four newly solid middle-layer stems. The reproduced baseline records
19 frames with both head and body bone-center rays blocked by native bark.
Three `CylinderShape3D` segments now enclose its exact 216 native bark corners,
using the existing forest's smooth static-cylinder convention. A pinned packet
hash admits the known baked owner; rendering and ordinary camera/controller
settings are unchanged. One body, three shapes and four nodes are added, with
no new render geometry, texture, material, dependency or per-frame script.
Startup work/state is bounded by those 216 corners. Native physics cost has not
been isolated. The maximum conservative whole-segment radial shell is 17.74 cm;
this is not a measured gap at the player's feet. Unsafe-support metadata keeps
the caps out of ordinary support, Float support and recovery-site selection.

The earlier three-convex-shape trial corrected camera occlusion but failed real
lateral movement: zero sliding displacement. Its failed receipt is retained at
`reports/outer-tree-20261011-115100-65432/`. The cylinder successor slides 1.1055 m
laterally and retains approach obstruction, retreat, every-tick no-overlap,
no unwanted paving step and unsafe-cap refusal. No controller workaround was added.

The integrated `outer-tree` suite passes 17 integration/camera checks, 19 existing
trunk checks and six new contact checks across 855 movement ticks. At fixed
30/60 rendered FPS, respectively 225/450 east-route camera samples show zero
simultaneous head/body bark blockage, lens overlap, full fading or behind-camera
targets. These are sampled native bone-center rays and lens queries, not
whole-image visibility or exhaustive path/frustum coverage. Removing and
reinstalling the owned body preserves other mesh/material/contact bindings.
The diagnostic reads raw native surface arrays and indices: Godot's
`Mesh.get_faces()` delegates to `TriangleMesh`, which snaps vertices; applying
that snap before versus after batch transforms caused earlier identity failures.
Exact raw-array matching fixes the diagnostic without weakening its equality.

Fresh broader runs pass 137 environment assertions and 295 gameplay assertions
across 15 scenarios. Four Python runner failure tests pass. The 120-second
night/rain route passes unchanged limits at 1920 x 1080/default VSync:
**p95 16.163 ms / p99 18.067 ms**, 10,121 frames, two loops and zero stalls.
Read-only hashing of historical import caches briefly overlapped this run;
this is an observed route result, not a controlled cost/speedup comparison.
GPU/presentation, thermal and physical-device performance remain unmeasured.

The new silent offline30-FPS recording contains 643 fully decoded 1280 x 720
frames (21.433 seconds), with seven decoded samples at 3, 7, 11, 14, 15, 18 and
20 seconds. The sampled formerly blocked turn now shows the character; the
unsupported home and unfinished background remain visible. Its MP4 is
31,011,622 bytes. The working AVI was removed only after complete decode and
source/stat/hash verification. Source and fixtures stayed exact during native
runs and capture. Continuous motion, manual controls and live listening remain
unverified. No app was exported; mac063 still predates these source changes.

The separate native house survey matches all three rendered stem packets
exactly. The nearest home has sampled support gaps of 1.918–1.948 m; the second
has 4.592–4.623 m. The third already meets some rock/moss below its base, but
queries starting at base height cannot rule out rock penetrating above it.
Foundations remain open; preserve the reference's elevated homes and rock ledges.
Other original visual-only trunks also remain outside this single-tree fix.

Evidence: `reports/outer-tree-20261011-115903-65910/`,
`reports/outer-tree-60-20261011-115931/`,
`reports/environment-20261011-120600-66258/`,
`reports/acceptance-20261011-120000-65964/`,
`reports/benchmark-20261011-120622-66372/`,
`reports/outer-tree-movie-20261011-120845/` and
`reports/tree-inventory-20261011-114719/`. Exact receipt hashes are in the compact
summary. Rollback: Git `9936133`.

## Historical imported-cache duplicates

The authorized cleanup removed only 113 historical `.godot/imported` directories:
3,390 files, each matching the retained combined238 canonical cache by name,
length and SHA-256. Selected allocated bytes totaled 1,210,810,368 (1.128 GiB).
All payloads and metadata were rechecked before removal, with file-descriptor
path handling, symlink refusal and per-directory quarantine. The 30-file canonical
copy remains exact and can restore the cache payloads. Original file modes and
mtimes are retained in the audit; inode/ctime identity cannot be restored.

The final guard passes 35,207 non-target entries in the affected historical
projects. It checks metadata for all entries and hashes ordinary local source/
control files up to 1 MiB; it does not rehash every large historical asset.
Editor state, source, assets, references, saves, apps, archives and unique evidence
were excluded from removal. All 303 current tracked payloads also remain exact
against the committed source manifest. Seven temporary-fixture safeguard checks
exercise the cleanup helper; they are separate from the actual cleanup receipt.

Available space was 12,451,028,992 bytes before removal and 12,440,399,872 at the
immediate sample. That first sample showed no reclaimed space. After delayed
accounting and lossless gzip compaction of the cleanup's own preflight receipt,
the later sample is **13,640,122,368 bytes (12.70 GiB)**, an observed increase of
1,189,093,376 bytes. APFS sharing/delayed accounting and other activity prevent
exclusive attribution. The 12 GiB export preflight is met at this sample; it must
be checked again when exporting. The retained 18,404,635-byte preflight payload
fully rereads from its 2,232,885-byte gzip with the same SHA-256. No further archive
compression or source refactor was needed for this recovery.

Receipts: `reports/perimeter-contact-development/storage-import-cache-audit.json`
and `storage-cleanup-outer-tree-01/` beneath the same directory. The cleanup changes
only historical generated caches; it supplies no runtime performance claim.

## Closest-home support trial — not adopted

An isolated 128-triangle stone support passes 23 native checks, 171 actual
approach/slide/retreat ticks, six camera poses and 12 fully decoded paired
day/night PNGs. The 3,345-byte material-free resource reloads with all native
channels/configuration/buffers exact. Original static owners, house geometry,
materials and RNG are preserved; 51 known sky poses/visibility values follow
the camera/time across phases and are held exactly within each frozen pair.
The ground-footprint check uses local, power-of-two-scaled native polygon
clipping and double-scalar area arithmetic, preserving its original thresholds.
The pinned [Godot implementation](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/core/math/geometry_2d.cpp)
uses five decimal places for polygon clipping. Earlier fixture precision, null
resource, inherited-name and live-sky preservation failures remain retained.

The support was **rejected at visual review**: its regular outline, horizontal
bands and near-vertical sides read as a cylindrical pedestal, not a natural
reference rock ledge. It is not installed, exported or performance-qualified.
Evidence and the frozen candidate remain at
`reports/house-support-20261011-122900/`; the reusable isolated fixture is
`reports/perimeter-contact-development/house_support_trial_v6.gd`. The nearest
home's foundation and the other two homes remain open. Keep house elevation and
existing materials, and refine the rock silhouette before integration.


## Closest-home foundation and native contact margin

The installed v12 rock closes the measured ground gap beneath the closest
background home while retaining its authored elevation, native house mesh and
shared materials. The cached resource is 6,771 bytes, 160 triangles/480 corners,
one render node and one matching concave static shape (four nodes total). It
reuses the existing deterministic rock authoring and `stone_light`; no texture,
shader, dependency or per-frame script was added. Startup validation scans fixed
native vertex packets, O(V) work/temporary arrays. GPU/physics cost is not isolated.
The large plain side rock, rear landscape join and other two homes remain open.

The isolated v10 support passed local tests, but broader traversal found nine
fully faded west-corridor camera samples. v12 narrows/shifts the lower west face;
the camera regression clears. An intermediate shifted-foot topology failure
remains recorded. The original 3 mm character margin also reproduced about
1.07 mm of overlap with an existing outer trunk. Native traces show ground/trunk
contact composition changing after active foundation registration, without a
foundation contact; the engine-internal cause is unproved. Removing the support
passes; a separate 5 mm native-margin trial passes with it installed. Production
now uses 5 mm. Speeds, capsule, slopes, stepping and overlap thresholds are held.
[Godot's pinned CharacterBody source](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/physics/character_body_3d.cpp)
passes this existing parameter to grounded motion/recovery. The reported 4.0713 mm
motion depth is the overall result, not a per-contact measurement, as confirmed
by [KinematicCollision3D](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/physics/kinematic_collision_3d.cpp).

Fresh integrated results:

- Foundation: 26 checks, 156 movement ticks, 23 native trunk-shape guards,
  six camera poses and 12 fully decoded paired day/night PNGs. Actual installed
  render/contact arrays, original mesh/material/physics identities and RNG pass.
  The MultiMesh underlying mesh identity is now included. Its first test edit
  misplaced the known live-sky visibility slot; that failed receipt remains,
  followed by the corrected strict pass. Full poses/visibility are held per pair;
  only 51 known camera/time-following sky rows are qualified across phases.
- Trunks: 855 movement ticks at both 30 and 60 rendered FPS, with 225/450 sampled
  camera rows and zero blocked bone centers/lens overlaps. These are native
  sample checks, not whole-image/exhaustive visibility or manual feel approval.
- Paving: all 58 movement routes and 7,337 callbacks pass. 164/165 assertions pass;
  the sole aggregate upper-soil/near-cut moving-contact gate still fails, with
  zero roof credit and zero ambiguous classifications. Four separate gap routes
  pass 20 assertions and 533 ticks. No movement/contact gate was weakened.
- Environment: 137/137; broader gameplay: 295/295 across 15 scenarios.
- 120-second night/rain source route: **p95 16.254 / p99 18.181 ms**, 10,079 frames,
  two loops, zero stalls, 1920 x 1080/default VSync. Unchanged 16.7/33.3 ms limits
  pass. No controlled speedup, GPU/presentation, thermal or mobile claim follows.

The new silent offline30-FPS movie has 643 decoded 1280 x 720 frames (21.433 s),
30,065,733 bytes. Seven sequential samples fully decode; 14/15/18-second frames
were reviewed and show the support and visible character. Continuous motion and
live listening remain unverified. The temporary AVI was removed only after full
MP4 decode and source/stat/hash readback. A first RGB sample was refused by the
RGBA checker; explicit RGBA extraction is the retained passing successor.

Receipts: `reports/house-foundation-20261011-131416-70722/`,
`outer-tree-20261011-130500-70072/`, `outer-tree-60-20261011-131725/`,
`gap-step-20261011-130611-70129/`, `traversal-20261011-131513-70801/`,
`environment-20261011-130627-70155/`, `acceptance-20261011-130641-70165/`,
`benchmark-20261011-131028-70406/` and `outer-tree-movie-20261011-131745/`,
all beneath `reports/`. Full hashes and failed-trial paths are in the compact
summary. Runtime stayed unchanged during these checks; the later fixture-only
identity check has its own passing run. Rollback: Git `e7482ce`. No new app is
claimed by this source checkpoint.


## mac064 packaged and uploaded checkpoint

The current source checkpoint `e934f37` is exported as a separate mac064 app.
Packaging, 12 exported startup/effects checks, four fully decoded captures,
strict ad-hoc signature and exact app/ZIP payload checks pass. The new profile
is `MUSH-mac064`; original profiles and source stay exact. Peak sampled owned
allocation was 806,232,064 bytes, below the 2 GiB ceiling. Verified temporary
export staging was removed; accepted/rollback apps and unique evidence remain.

The exported 120-second night/rain route passes unchanged limits:
**p95 16.644 ms / p99 20.498 ms**, 9,946 frames, two loops, zero stalls,
1920 x 1080/default VSync. Percentiles were independently recomputed from the
complete CSV. Its p95 headroom is only .056 ms; no controlled speedup,
GPU/presentation, sustained thermal or mobile qualification is claimed.
The 106-frame offline30-FPS clip fully decodes at1280 x 720 (3.533 seconds),
with a decoded AAC track. Neither continuous real-time motion nor listening
is established. Day/night exported stills were inspected; final art remains open.

The ordinary app reaches CLEARING_READY and is listed as running by CUA, but
window inspection returns `cgWindowNotFound`. Its owned PID81837 was terminated
and reaped after exact command verification. The failed result remains; no
ordinary save was created or Save/Continue pass transferred from older mac061.
Source, prior profiles and the app remain exact during this attempt.

The private [mac064 prerelease](https://github.com/xingzhao-ji/MUSH/releases/tag/mac064)
contains the 162,744,174-byte ZIP, SHA256
`e2acdb066d5edc0ab285f0b55aefa0f04900478d743b353a4143c9ac815d10d4`.
The GitHub release API independently reports matching size/digest and target
commit; no duplicate asset download was needed. Full receipts are under
`builds/mac-20261011-132118-71306/verification-20261011-132315-81595/`, with
`DELIVERY.json` in its parent. UI/upload receipts are under `reports/mac064-ui/`
and `reports/mac064-preparation/`. Launch details and open gates are in
[MAC-CANDIDATE.md](MAC-CANDIDATE.md).


## Paving support-envelope diagnostic

A separate query-only diagnostic admits the unchanged native capsule, contact
packet and 52-face upper-soil roof. All 15 declared near-cut points have their
soil sheet confirmed by short native rays; none was substituted or inconclusive.
Thirty downward `body_test_motion` queries, with both recovery modes, retain
all 196 indexed contacts, 4–12 per query, below the capacity of16. None provides
a qualifying sole roof-region floor contact. Of the contacts,162 classify to the
upper stones;34 fall outside the classifier's upper regions and remain unclassified.
Hypothetical end roots stay 40.6–146.1 mm above the sampled soil sheet. This
supports capsule bridging over the recessed joint, not exhaustive unreachability.

All56 technical-integrity checks pass; actual player pose/state/counters,
settings, registered owner and source remain exact. No movement or teleport was
executed, no ordinary-input follow-up was justified by an eligible query, and no
traversal coverage is earned. The full-route gate remains failed. No runtime,
geometry or mac064 artifact changed. Evidence:
`reports/paving-support-envelope-20261011-133348-82387/`; reviewed fixture/runner
are retained in `reports/perimeter-contact-development/`, with hashes in the
compact summary. A broader reachability proof remains separate from the passing
58 actual movement routes.


## Report compaction and distant-home inspection

A bounded path-preserving cleanup compressed 316 historical JSON reports after
a three-copy native pilot and full target/parent admission. All 316 logical
payload hashes match an independent reread; the 165 immediate-parent membership
and non-target entry guards pass. Source payloads stay exact. Allocated report
storage fell by **917,540,864 bytes (875.04 MiB)**. The execution observed
2,575,949,824 more available bytes; a later sample showed15,574,646,784 bytes
(14.50 GiB) free. Delayed APFS accounting prevents exclusive attribution.

Paths, contents, mode, owner, mtime and ordinary xattrs are preserved. Inode,
ctime, birthtime and compression/allocation metadata intentionally changed.
The compressed manifest retains the original metadata; verified decompression
can restore the logical files but cannot reconstruct those identity timestamps.
Unique assets, sources, references, saves and apps were outside the target set.
Receipts: `reports/storage-report-compaction-20261011-134407/`.

The unchanged scene also passes a 20-owner,195-site native geometry inventory
and six fully decoded day/night captures. Queries retain every raw-triangle
crossing from above each owner's maximum Y, avoiding the former base-start ray
limitation. The closest home's installed ledge overlaps its base by6 mm. The
second home has only soil4.592–4.623 m below its base. The third home has existing
rock/moss3.141–4.054 m above its base and is hidden in the captured views.
These are confirmed scenery defects; no home or bank was modified or accepted.

The first fixture failed on a Script.resource_path access before scene startup;
its receipt stays failed. The successor corrects that access and explicitly
separates ordinary saves/settings from generated log rotation/cache. Source,
ordinary save/settings payloads, mesh/material/body ownership and RNG stay exact.
Evidence: `reports/house-bank-inventory-20261011-134645-84240/`. The fixed cameras
are diagnostic views, not played-camera, movement or performance acceptance.


Two isolated home2 support variants pass16 native checks each and12 fully
decoded paired PNGs each, including closed finite geometry, nondegenerate UVs,
finite unit/orthogonal tangents, all64 stem sites, full soil-foot burial, guarded
rear crossing witnesses, resource round-trip and actual trial removal. The
first precursor failed a rear witness and remains failed. Both passing variants
are **visually rejected and not integrated**: they replace the floating gap with
an oversized plain pedestal/wall. Some fixed wide views are obscured by trees
or leaves; the final elevated rear view is diagnostic, not a played pose.

Each temporary variant uses128triangles, one shared opaque stone material, one
identical concave shape and four nodes, with no per-frame work. Those counts do
not establish frame-time cost. Player traversal, camera clearance and continuous
motion were not exercised. Source and ordinary saves/settings remain exact.
The next correction should test coherent whole-home placement on the existing
bank after every batched part and its window light is positively mapped.
Receipts: `reports/home2-bank-trial-20261011-140155-87764/` and
`reports/home2-bank-trial-20261011-140519-87894/`; current mac064 stays unchanged.


## Complete distant-home placement on existing terrain

The second home previously floated 4.59–4.62 m above soil; the third was buried
beneath the existing bank. A whole-home translation now places them at
(21.25, 4.68, -25.0) and (-15.5, 5.2, -24.5). All 18 mapped parts and the actual
window light move coherently for each home. Existing terrain, the closest-home
foundation, unrelated native vertices and every non-position channel stay exact.
No new bank pedestal, material, draw node, collider, triangle or frame loop is added.

The chosen approximation embeds the lower cylindrical stems in the existing rock.
Native samples show 0.0369–0.5237 m burial for home2 and 0.0343–0.5331 m for home3;
nine conservative window sites per home retain at least 0.2625 m / 0.2813 m clearance.
These are sampled anchoring checks, not exhaustive whole-foot/decorative coverage
or played-camera reachability. Home2 reads as grounded in day/night views. Home3
is restored above the bank in an elevated diagnostic view but remains hidden by
foliage from the retained ground camera. That art defect remains open.

The compressed Godot MeshLibrary is 1,941,665 bytes, SHA256
`9fd28d80133aedc92364afff0afe3aaa255f9ae43638864989731357ce3fd1bf`.
It reuses 16 existing batches/239,574 corners, translating 157,476 selected corners.
The 176,068-byte proof pins saved/fresh-reloaded native arrays, packed buffers,
lightmap hints, node/material bindings, parent poses and actual window lights.
Godot/native project helpers replace procedural construction during gameplay;
no add-on, additional license or external dependency is introduced.
Startup validation is linear in admitted payload bytes/corners and has temporary
array/hash storage; retained original/candidate position payloads alone total
5,749,776 bytes before other buffers. Artifact file size is not runtime memory.
No permanent undo owner or per-frame GDScript is added. Startup cost, incremental
peak memory and GPU cost were not isolated. Git `b21ac33` is operational rollback;
setting the installer's ENABLED flag false refuses startup rather than selecting
a baseline mode. Failure-path rollback is reviewed code, not fault-injected proof.

Isolation receipts retain exact native packet mapping, daytime/nighttime paired
trials, compressed save/reload and repeated prebuilt install/restoration:
`reports/home-packet-admission-20261011-141924-88807/`,
`reports/home-relocation-preview-20261011-142424-89079/`,
`reports/home-relocation-preview-20261011-142513-89150/`,
`reports/home-relocation-preview-20261011-143337-89571/` and
`reports/home-relocation-preview-20261011-143523-89671/`.
Earlier oversized added-bank variants stay visually rejected; their passing
technical checks were not used as art acceptance.

Fresh actual-source import passes. `home-placement` passes 14 checks and all 16
1280×720 PNGs fully decode, with 8 original/installed day/night pairs and exact
installed-state restoration. Broader gameplay 295/15, environment 137 and
foundation 26 checks pass; the foundation route covers 156 movement ticks and 23
native trunk shapes. No source payload changed during these runs. Five verifier
unit tests pass, including rejection of duplicated camera rows. The tightened
ordered-label inspector rereads all 16 retained images successfully; this reread
is not another native launch. Fixture baseline/current swaps are distinct from
injecting a loader failure.

The fresh 120-second source night/rain route passes unchanged 16.7/33.3 ms limits:
p95 16.136 ms, p99 18.102 ms, 10,079 frames, two loops, zero stalls at 1920 × 1080/default VSync.
No causal speedup, GPU/display, thermal, listening, continuous-motion or physical
mobile qualification follows from that result. The existing upper-soil paving
contact-coverage gate remains failed; unchanged 58 movement routes retain their
previous evidence, not a fresh rerun. Full reference/art acceptance remains open.

Receipts: `reports/home-placement-20261011-143727-89753/`,
`reports/home-placement-regression-20261011-143849/` and
`reports/mac065-preparation/placement-reinspection.json`; exact suite paths and
hashes are in the compact summary. mac064 is a separate frozen older artifact.


## mac065 export and authorized as-is upload

The universal mac065 app packages source `1777353bef29cdf3b9d4b7250121a7ed36d12c8c`
with a fresh `MUSH-mac065` save profile. All 12 exported startup checks, four fully
decoded still captures, strict ad-hoc signature and exact ZIP readback pass. Only
arm64 ran. Source, prior profiles, ordinary candidate slot and app payloads remain
exact across verification. No ordinary candidate save was created. The owned
processes exited and were reaped; temporary export staging was removed.

The exported 120-second night/rain route completes 9,622 frames, two loops and
zero stalls at 1920 × 1080/default VSync, but **fails p95**: 17.524 ms against
16.7 ms. p99 is 22.847 ms against 33.3 ms. The CSV metrics validate before the
threshold assertion; the receipt stays failed. The passing source result and
frozen mac064 result do not waive this failure or prove its cause. No repeat was
run just to obtain a pass. Upload as-is is explicitly authorized by the user.

The offline in-engine clip fully decodes as 106 H.264 frames, 1280 × 720 at 30 FPS,
3.533 seconds, with stereo 48 kHz AAC. Its 3,595,003-byte MP4 has SHA256
`d815d59996d8c5055d59d802263a6527516c1bb4c2f3342ca005636e614bc782`.
The intermediate AVI was removed only after counted-frame/audio/full-decode
checks. It is not real-time pacing, manual motion or speaker-playback evidence.
Ordinary mac065 UI was not exercised; prior mac064 `cgWindowNotFound` remains
recorded, and older mac061 Save/Continue observation does not qualify mac065.

The private [mac065 prerelease](https://github.com/xingzhao-ji/MUSH/releases/tag/mac065)
contains the 164,449,080-byte ZIP, SHA256
`1ccec56f30c9d1ff464a7322eb876c175c3668f497b75de340bbbbd7a8fde1b9`.
The GitHub API independently confirms asset size/digest, exact release text and
commit-tag binding; no duplicate asset download was needed. Receipts and
`DELIVERY.json` live under `builds/mac-20261011-144832-90462/`; export tests are in
`verification-20261011-145024-979/`, and upload checks in
`reports/mac065-preparation/`. Launch notes and remaining work are in
[MAC-CANDIDATE.md](MAC-CANDIDATE.md). Full art, manual play, listening and physical
mobile acceptance remain open.

## Build import exclusion and mac065 diagnostic repeat

A tracked `builds/.gdignore` now excludes local exports and their test captures
from editor import scanning, using the existing reports-folder pattern. Fresh
Godot import passes; the asset index contains zero build directories after having
46 before. All 301 existing build files retain exact bytes, mode and modification
time. Other build outputs remain Git-ignored. No caches, captures or apps were
deleted, and no reclaimed bytes or runtime speedup are claimed. This prevents
unnecessary future import work. Rollback is Git `b0fb964`. Receipt:
`reports/build-import-exclusion-20261011-164816/receipt.json`.

One unchanged mac065 diagnostic repeat, with exclusive engine ownership and
recorded power/OS activity, also fails the existing p95 budget: **18.460 ms**
(p99 19.674 ms), 7,167 frames, two loops and zero stalls over 120 seconds at
1920 × 1080/default VSync. CSV metrics validate independently before threshold
failure. Source, prior profiles, ordinary save, app and ZIP preservation pass.
AC power and no reported OS thermal warnings were recorded; this is not thermal
qualification or proof of a cause. No additional rerun was used to seek a pass.
Receipt: `reports/mac065-export-repeat-20261011-150637/receipt.json`.

## Foliage isolation and pacing diagnosis (runtime unchanged)

The current 120-second mac065 failure remains failed. Read-only analysis of the
source/first export/repeat CSVs finds that the repeat averages 59.717 callbacks/s
with median 16.657 ms, while renderer CPU p95 falls to 2.216 ms. Reported VSync
and refresh remain 1/120 Hz; duration-weighted draw/primitive counters differ by
less than 0.02%. These are callback/counter observations, not proof of a display
cap, GPU cost, or a cause. The earlier first-pass renderer CPU spike does not
reproduce. `reports/mac065-performance-review-new/repeat-analysis.json` retains
11 independently checked input hashes.

A separate unchanged-app 60-second diagnostic uses the installed macOS sampler
on the owned process for two requested eight-second windows. Both samples and
the bounded engine exit complete, with source/app/ZIP/profile preservation exact.
Main-thread observations include Metal completion and IOSurface event waits;
44–49% of terminal observations remain unsymbolized. The second sample spans
five route steps, so its wait share cannot be assigned solely to the hotspot.
Sampling affects timing: this is neither a 120-second pass nor an optimization.
No quality reduction or production performance change was selected. Receipts:
`reports/mac065-sampled-diagnostic-20261011-170320-3955/receipt.json.gz` and
`reports/mac065-performance-review-new/trace-analysis.json` (seven checked inputs).

The third home's obstruction is reproduced in the actual Main scene. Exact
native geometry admission matches all 55 middle-layer chunks. Two center-ray
queries identify tree7 (low) and tree8 (medium), both without live contact bodies.
An initial helper API error remains failed; its successor passes eight checks.
This is static native triangle attribution, not full-window or moving-camera
visibility. Receipt: `reports/home3-foliage-attribution-v2-20261011-165509-3473/`.

An isolated trial raises both trees to the existing tall cohort through the
original generator. All 30 roots and RNG states, all 28 other trees' poses,
shared native meshes/materials, 450 instances, 208,920 triangles and 55 batches
remain exact; existing physics stays live and unchanged. The first capture
attempt obtains no fresh drawn frames and remains failed. A successor adds
independent draw/window diagnostics and stops on the first undrawn view; all
15 checks and 12 fully decoded 1280×720 images pass with complete restoration.
No draw fallback, quality change or relaxed assertion was used. The earlier
draw inactivity's cause remains unproved.

All six day/night pairs were visually inspected. The nearer view now exposes
the window beside a trunk, but foliage still obscures the approach. The central
clearing composition shows no material visual change. The trial is **not
integrated**: a center-ray hit is insufficient to describe the full visible
window. Broader window/canopy attribution is the next scenery diagnostic.
Production runtime, the mac065 app and prior acceptance results are unchanged.
Receipt: `reports/home3-cohort-diagnostic-20261011-171444-4616/receipt.json`.
Earlier failed preview: `reports/home3-cohort-preview-20261011-170454-4134/`.
Still frames do not qualify motion, manual play, live audio or physical devices.

## Verified duplicate extracted-app cleanup

Free space dropped below the 12 GiB export preflight floor. The unaccepted
mac062/mac063 extracted apps were compared file-by-file with their retained ZIPs
and original package manifests, and both strict ad-hoc signatures passed. Native
attribute scans found no extended attributes requiring separate retention. Only
those two duplicate app folders were removed; all 14 file payloads and executable
permissions are preserved in their ZIPs. Both archives fully reread afterward.
mac064/mac065, accepted057, rollback055, source, profiles and unique captures remain.

The target files accounted for **782,827,520 allocated bytes (746.56 MiB)**.
Observed free space rose by 779,640,832 bytes to **12.26 GiB**; APFS accounting and
other activity prevent exclusive attribution of that difference. All 335 other
build entries, current source payloads and prior profile metadata pass exact
preservation checks. Only the two containing directories' size/mtime/ctime were
allowed to change with removal. A first metadata preflight stopped before any
deletion; its failed receipt is retained.

Receipt: `reports/duplicate-old-app-cleanup-v2-20261011-172421/receipt.json`;
`archive-mode-readback.json` independently checks all retained file permissions.
The saved `before.json` records full app identities. Recovery is extraction of
each retained `MUSH.zip` into its original build directory; recreation necessarily
changes inode/ctime. No unique build, source, asset, save or evidence was deleted.


## Third-home view and benchmark draw qualification

The installed source raises only seeded trees 6, 7 and 8 to the existing tall
cohort. All 30 roots, random-call order and the other 27 trees remain exact.
Native meshes/materials are reused: 450 instances, 208,920 triangles and 55
spatial batches remain. Cohorts are now 12 low / 7 medium / 11 tall. Tree6's five
existing cylinder shapes regenerate coherently; no new body, material or frame
loop is added. The optional root-offset helper is not integrated.

The immediate mixed-layout preview passes 15 checks and 12 fully decoded
1280 × 720 stills. Reviewed pairs expose the window in both fixed ground/approach
views in day and night; a natural partial trunk/roof overlap remains. The
integrated forest suite passes **29 checks**, ten clear static window segments,
20 native stem/collider matches, 36 camera poses, four contact cases / 19 checks
and ten decoded images. Its “before” uses the preserved all-tall constructor,
not the immediate mixed predecessor. The separate preview supplies that direct
comparison. Two explicit [RenderingServer redraws](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw) are used for frozen stills;
this does not qualify normal presentation, motion, shader-displaced pixel
visibility or benchmark timing. Earlier passive-draw failures remain failed.

Fresh gameplay passes **295 assertions across 15 scenarios**, with source
contents unchanged. Receipts:

- `reports/home3-cohort-explicit-three-20261011-175429-9668/receipt.json`
- `reports/forest-layers-20261011-180716-11086/result.json`
- `reports/acceptance-20261011-181134-11368/result.json`

The benchmark now records Engine.get_frames_drawn in JSON for every measured
CSV interval, including its preceding callback baseline. Validation requires
strictly positive advancement for every sample and rejects absent, partial,
frozen or decreasing telemetry. The 19 CSV columns and 16.7/33.3 ms budgets are
unchanged; benchmarking issues no explicit redraws. Eight runner unit tests
pass, including advancing, frozen/backward and missing/partial counter cases.
This detects undrawn callback intervals, not viewport pixels or display
presentation. Historical receipts are not retroqualified.

The current 120-second night/rain source benchmark passes: **p95 11.575 ms /
p99 13.188 ms**, 13,889 samples, two loops and zero stalls at 1920 × 1080,
VSync 1. Engine draw advancement is strictly positive for every measured
callback interval. No GPU/display, physical-device or causal improvement is
proved. Receipt: `reports/benchmark-20261011-182401-12470/result.json`.
mac066 export is planned; no new app, archive or exported benchmark is claimed.
The authorized as-is mac065 upload and both failed p95 routes remain failed.

Two ordinary mac065 UI sessions now qualify Begin, pause, Save & quit and
relaunch/Continue restoring Glow. The second session also observes night/rain
selection, settings navigation and Float toggle. Both owned processes exited 0
and were reaped, preserving source, app/archive and prior profiles. No third
relaunch verified the second night/rain save. Evidence:
`reports/mac065-continue-ui-20261011-173926/ui-observations.json`, with both
session receipts linked there. Dummy audio leaves listening unverified.
Sustained manual movement/camera comfort, continuous motion, whole-game art,
physical phones and paving contact coverage remain open.


## mac066 packaged verification

Source `b5c9f616ecfe6b1937f185a8dc1eb4dcdaea051e` produced
`builds/mac-20261011-183516-13113/MUSH.app`. Package startup12, Universal
architecture, strict ad-hoc signature and ZIP readback pass; only arm64 was run.
ZIP164,451,093 bytes, SHA256
`a43cff3de58902b4c6004ba321541ab4d65ea844605fb1c4e3184f4f5f87e8d5`.
Temporary export staging was removed after verification.

`verification-20261011-183801-23748/result.json` records a **failed** first
capture phase: one day image, then a 120-second timeout; the process was terminated
and reaped. Native CUA access also failed with a pipe startup error. The exact
cause of stopped drawing was not established. Benchmark and clip phases passed.

The 120-second exported night/rain route passes unchanged16.7/33.3ms limits:
**p95 10.619 ms / p99 13.759 ms**, 15,177 samples, two loops, zero stalls at
1920 × 1080/default VSync. Every callback interval has advancing engine draw
counts. Root independently re-ran the CSV/draw inspector and matched the native
executable/PCK fingerprint against the package. No explicit redraw was used.
No causal speedup, GPU/display presentation, thermals or mobile result is claimed.

`capture-topmost-20261011-184351-24527/result.json` is the passing successor:
the same unchanged app, four full960×960 PNG decodes, requested window flags
`--windowed --always-on-top --position 80,80`. Root reviewed all four images.
This qualifies fixed exported stills, not ordinary UI, continuous motion or
normal presentation. The earlier timeout is retained. The separate offline
MovieWriter clip fully decodes106 frames at1280×720/30FPS,3.533333s, with AAC
stereo48kHz audio; its intermediate AVI was removed after readback. No live
listening or continuous-motion judgment was earned.

Both verification runs preserve source, prior profile metadata, ordinary mac066
save (absent), app/ZIP metadata and payloads, and package receipt. Current ordinary
UI remains pending. Paving contact coverage and art/terrain/character issues
remain open. `DELIVERY.json` links all receipts and exact asset hashes.

The canopy adjustment reuses native geometry and changes only startup selection
for three indices: the existing O(N) forest construction and fixed450 instances
are retained, with constant additional selector state and no custom frame loop.
The diagnostic benchmark adds one draw-counter sample per existing interval:
amortized O(1) sampling and O(F) stored counts for F frames, only under the test
hook. Incremental GPU cost and peak memory were not isolated.


## Additional duplicate mac064 cleanup

`reports/duplicate-mac064-cleanup-20261011-185303/result.json` records removal
of only `builds/mac-20261011-132118-71306/MUSH.app`:391,745,536 allocated
file bytes (373.60MiB). All seven files were matched against the retained ZIP,
including full CRC readback and POSIX modes; strict native codesign verification
passed and no xattrs were present. A second pre-deletion read and post-deletion
archive read passed. The390 non-target build entries, source and all profile
metadata remain exact. The mac061 extracted app was already absent.

mac065/mac066 and accepted057/rollback055 remain extracted. Recovery of mac064
is extraction of its retained `MUSH.zip` into the original build directory;
inode/ctime necessarily change. The immediate observed free-space sample is
12,795,944,960bytes (11.92GiB); no exclusive APFS free-space attribution is made.
The10GiB runtime floor remains; any later export needs fresh12GiB admission.


## Bounded slope-adjusted paving contact diagnostic

The previous direct-over-roof probes did not account for capsule tangency on
sloped triangles. This diagnostic derives the lower-sphere center from the actual
0.28 m radius capsule and offsets each roof point along its native face normal.
The available near-cut inset pool contains 47 points across 14 walkable faces;
24 samples cover all 14 faces and offsets up to 8.524 cm. Each receives one
short roof-confirmation ray and two downward native capsule queries, with the
actual 5 mm margin and both recovery modes. No body is teleported or driven.

The native run passes 107 diagnostic checks. All 24 rays confirm the roof,
but the 48 capsule queries yield zero qualifying roof contacts and no saturated
contact lists. The 218 indexed contacts comprise 188 upper-stone contacts and
30 without a classified upper region. Player/query state, installed geometry,
source, ordinary saves, prior profiles and retained app/archive metadata remain
exact. The process exits 0 and is reaped. This strengthens the bounded bridging
evidence; it does not prove universal unreachability or a movement defect. The
164/165 traversal result and its failed coverage gate remain unchanged.

Receipt: `reports/paving-tangent-20261011-191956-29706/receipt.json.gz`.
Native report: `native/tangent-envelope.json`, SHA256
`efebf6e9cfeb43dd4317796612e37f425e53f9b644deea87348f6adafb1d3859`.
No runtime change, new dependency or performance gain is claimed.


## Cream creature: single-tail refinement

The user chose refinement of the existing cream woodland creature. Source
`a93a12ab350b0eb90a2bd4bf6cf34ce165d8bf89` replaces five bead-like tail lobes
with one tucked round ellipsoid using the existing TailMesh, cream material and
bone. The construction loop is omitted, keeping the mesh registry coherent.
Face/body parts, bone rest poses, clips, paw modifier, camera and physics stay
unchanged. Rollback is `9874b92d65679ee6625fffa4511b7f6f64f8cfff`.

Isolation passes ten checks and eight decoded 960-square before/after images.
Fresh ordinary-source startup passes ten checks and four decoded stills. All
twelve images were reviewed: the round rear/side silhouette is cleaner. A faint
previous-tail outline in the comparison side view is absent from fresh startup;
its transient rendering cause was not established. These explicit-redraw stills
prove depicted states, not animation or display presentation. A first fixture
parse error and a later stale six-part admission check are retained as failed
attempts, separately from the passing successors.

The actual character now creates **24 mesh nodes / 26,112 triangles**, previously
29 / 31,552: five fewer nodes and 5,440 fewer triangles. No new texture, material,
shader, animation, collider or frame loop is added. Startup construction and the
existing per-frame fade remain O(M) for M character meshes, with five fewer
entries. Geometry counts do not measure GPU savings, memory or phone performance.

The first full regression fails T01 after its held movement action clears before
the test releases it; the player is grounded and only a floor contact is recorded.
The other 14 scenarios pass. Its ordinary-save guard also incorrectly includes
five existing crash/fault scratch directories. A separate metadata audit confirms
those were the only changed buckets; the original receipt remains failed.
An isolated original T01 passes all 18 assertions with a read-only input/focus
observer and a topmost window. Its wrapper reads an incorrect log filename;
independent readback verifies the completed native pass without rerunning it.

One subsequent full run with that observer/window configuration passes
**295/295 assertions across 15 scenarios**, preserving source, ordinary saves,
prior profiles and retained apps/archives. The five scratch outputs are explicitly
declared before that run. No input, controller, route, deadline or assertion was
changed. The original input-loss cause remains unconfirmed; the
[pinned engine clears pressed events on application focus transitions](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/scene_tree.cpp#L869),
but the original run did not record those notifications.

The independent 120-second night/rain source benchmark passes unchanged budgets:
**p95 12.275 ms / p99 13.640 ms**, 13,027 samples, two loops and zero stalls at
1920×1080/default VSync. Every measured interval advances engine draw counts;
the CSV/draw inspector was independently rerun. No forced draws or input observer
run in this benchmark. This is neither a causal speedup nor GPU, thermal or
physical-device qualification. All owned processes exited and were reaped.

Receipts: `reports/character-tail-20261011-193551-31339/` (isolation),
`reports/character-tail-20261011-194139-31811/` (installed stills),
`reports/character-tail-regression-20261011-194307-31877/` (failed first run),
`reports/character-input-20261011-195834-33678/` (isolated T01/readback),
`reports/character-full-input-20261011-200559-34273/` (full pass), and
`reports/character-tail-performance-20261011-200132-34018/` (benchmark guards).
The exact source benchmark is `reports/benchmark-20261011-200132-34018/`.

The downloadable mac066 app remains unchanged and predates this source refinement.
No new export, continuous-motion, live-listening or physical-phone acceptance
is claimed. Native UI automation still fails to start its pipe. Whole-game art
and the independent paving contact-coverage gate remain open.

## Scenery prototype: terrain blockout and walkable knoll route (2026-10-26)

Branch `prototype/scenery-first`, profile `MUSH-proto-scenery-20261025`, Godot 4.7.2 (SHA256 `c7cccbf8…718ccf`). Rollback: `git revert` the commit, or launch with `--prototype-scenery=off`.

- **Geometry correctness:** terrain, cap-top and stem normals are checked in the prototype report (`winding_ok`). The far layer (terrain, lake, giants, pillars, carpet) has no colliders and is a labelled visual blockout.
- **Route:** one `NaturalRoute` ribbon with its own collider starts flush on the baked collider seam (−2, 29), measured within 3 cm, and climbs 261 m to a southern knoll. The player's movement-only extension (`scripts/air_capsule_guard.gd`) adds the exact route corridor plus a 3 m approach strip. Safe, save and teleport positions still require the original box.
- **`route` suite: 18/18 checks** (`reports/route-20261026-012839-69055`):
  - continuous real-input walk from the original box to the knoll in 7,397 ticks, 100% grounded, no recovery;
  - camera clearance at least 0.77 m;
  - Glow twice and Float on the route end grounded;
  - both shoulders and the open end recover into the original box;
  - snapshot and teleport stay in the box.
- **Not covered by the route suite:** automated input only. No manual feel, no new-process reload, no Float hover near route edges beyond the tested press.
- **Regression and benchmark:**
  - Acceptance **295/295** with the route active (`reports/acceptance-20261026-013255-69263`).
  - Benchmark **p95 13.157 ms / p99 14.633 ms**, 13,143 frames, two loops, zero stalls (`reports/benchmark-20261026-013617-69441`). It measures the existing night/rain clearing route, not the knoll views.
- **Scenic suite:** 18 frames pass framing and floor checks. The vista canopy coverage gate **fails** (0.0177 < 0.02) and is recorded, not retuned (`reports/scenic-20261026-013128-69181`).
- **Earlier failures retained:**
  - one intermittent startup stall (`reports/scenic-20261026-001845-64501`);
  - route refusals for grade (24°) and turn radius (3.9 m), which prompted the redesign;
  - a rejected concave-knoll trial (4.3 m trail cut).

## Scenery prototype: environment art pass (2026-10-26)

What changed:
- **Terrain:** existing moss albedo (flat ground) and Rock01 (steep ground), world-space at real scale. Moss has no mipmaps (import unchanged), so it is fetched only within 80 m and replaced by its measured mean (`#2d4006`) beyond that.
- **Lake:** a transparent depth-tinted teal shader with ripple normals and a restrained horizon reflection.
- **Giants:** organic asymmetric caps with a fleshy rim, fine gills, freckles and soft stem glow, on fluted, gently bending closed-top stems. The hero stands on a mound.
- **Mesas:** domain-warped terraces.
- **Trees:** 45 copies of the existing forest-ring trees (same meshes and materials).
- **Distant forest:** a coarse clump forest only beyond 230 m, in 50 culled chunks.
- **Trail:** existing Rock01 earth.

Results on the committed source:
- `route` **18/18** (`reports/route-20261026-022917-72264`).
- Acceptance **295/295**, no exit leak (`reports/acceptance-20261026-023209-72404`). One earlier run on this pass passed every scenario but printed `2 resources still in use at exit`, and the runner failed it (`reports/acceptance-20261026-015518-70544`). A verbose rerun of the same command and a later official rerun were both clean. The cause is unconfirmed.
- Benchmark **fails**: p95 17.572 ms (> 16.7), p99 20.498 ms, 9,333 frames, two loops, zero stalls (`reports/benchmark-20261026-023613-72598`). A later run with the prototype layer fully off measured p95 16.435 ms (`reports/benchmark-20261026-022217-71958`), against 12.275 ms for that scene in an earlier session. *Hypothesis, not causal proof:* most of that gap comes from changing machine state (other applications were active); no controlled measurement of machine load was made. Separate benchmark runs minutes apart put the art layer's marginal cost at about 1.1–1.4 ms, which is also uncontrolled.
- Bisection receipts:
  - single-MultiMesh carpet: 18.352 ms;
  - chunked carpet: 17.69 ms;
  - half the trees: 17.83 ms;
  - gated moss fetch: 17.864 ms;
  - all new art off: 16.773 ms.
- `MUSH_SCENERY_DIAG` (empty by default) is the diagnostic-only switch used for that bisection.
- Scenic coverage gates still **fail**: ground-path 0.0034 < 0.004, vista 0.0119 < 0.02 (`reports/scenic-20261026-022455-72069`).

## Scenery prototype: art iteration checkpoint (2026-10-26)

Bounded visual passes made since the art pass:
- **Giant stem:** buttresses grown into the stem surface.
- **Landform:** eroded massifs and a watertight ~5 m detail patch over the rim view's cliff band.
- **Erosion and moss:** multi-scale erosion and mottled moss.
- **Haze and colour:** distance haze tuning, a varied far forest and natural greens.
- **Near trees:** existing dense leaf clusters on near trees with a 100 m distance LOD.

Current-state results:
- **Geometry checks** (scenic report): giant footing drift 0.0 m, route terrain drift 0.0 m, finite normals. Near-crown replacement is asserted at 19/19 target trees (98 crowns).
- **Costs:**
  - terrain 91,442 + detail patch 51,520 triangles;
  - trees 960,480 built triangles, including 729,120 for dense crowns drawn only within 100 m (193,440 active from the rim camera);
  - far forest 504,000;
  - 88 draw nodes.
- **Route:** **18/18** (`reports/route-20261026-034627-76262`).
- **Acceptance:** **295/295**, no exit leak (`reports/acceptance-20261026-034912-76366`).
- **Benchmark:** **fails**, p95 17.573 ms (> 16.7) / p99 19.984 ms, 9,365 frames, two loops, zero stalls (`reports/benchmark-20261026-034407-76147`). This is a single full-art run with the art enabled. It measures the existing clearing route, not the new views. Outside machine load is a *hypothesis* for most of the gap, not causal proof (see the performance diagnosis below).
- **Scenic:** the vista coverage gate still **fails** (0.0129 < 0.02) (`reports/scenic-20261026-034213-76048`).
- **Not evidence of quality:** none of this is art acceptance or reference parity.

## Performance diagnosis: in-process attribution (2026-10-26, diagnostic only)

This section is diagnostic only. It is not a benchmark verdict and changes no threshold.

What the measurements can and cannot show:
- **GPU time:** `gpu_render_ms` is 0.00 in every benchmark CSV, so Godot's GPU timestamps do not report on this Metal path and GPU time is unmeasured.
- **CPU submission:** CPU render submission is about 1.25 ms (p50).
- **Geometry counts:** primitives and draw calls do not track the frame-time differences between runs. The passing early prototype and the current failing build both show about 2.9M median primitives and about 1,200 draws. The prototype-off run had fewer primitives (2.43M) and was still slower than that passing run.

The `perf-probe` suite (`reports/perf-probe-20261026-040635-77196`) measures uncapped frame interval at 1920×1080, night and rain:
- **Method:** at four benchmark-route poses and the rim overlook, each art component's visibility is toggled inside one process in ABBA order. The interval is application throughput, not GPU time.
- **Cost of the whole art layer:** hiding all of it saved 0.0–1.4 ms per pose across three runs. The runs were `035657`, `040149` and `040635`; the first two have invalid tree rows because of a node-name detection bug, while the whole-layer rows are valid in all three.
- **Original scene alone:** with the art hidden, frames still take 11.0–15.3 ms uncapped at the route poses, against a 120 Hz cadence of 8.33 ms.
- **Individual components:** carpet, trees, near crowns, terrain, giants/rocks and water each sit within about ±0.7 ms of noise.
- **Interpretation (unconfirmed):** frame cost is dominated by the existing scene at these poses. With VSync at 120 Hz, p95 sits close to the 16.7 ms limit, so roughly 1 ms of art cost plus run-to-run variance moves it across that limit.

LOD walk:
- **Events:** 4 dense-crown switch events while walking the route.
- **Frames:** consecutive frames at the nominal 100 m crossings show no visible pop.
- **Limit:** Godot applies the switch with a 12 m hysteresis margin, so these stills may miss the switch moment. Popping is unconfirmed either way, and continuous manual motion review remains unverified.

## Near-crown LOD transition check (2026-10-26, diagnostic only)

The `lod-check` suite measures the dense-crown switch for the near batch closest to the route (25 crowns):
- **Method:** a fixed-orientation camera moves 130 → 70 → 130 m in 2 m steps, with world and environmental motion frozen.
- **Observed switch distances:**
  - on approach, between 96 and 94 m, with primitives going 510,880 → 826,020;
  - on retreat, between 118 and 120 m.

  This is Godot's hysteresis around the 100 m limit with a 12 m margin. Frames on both sides of each switch are kept.
- **Pop at one identical 95 m pose:**
  - **Before the fix** (`reports/lod-check-20261026-041514-77639`): 1.30% of pixels in the tree's screen rectangle changed by more than 24/255, against a 0.08% noise floor. Visually, the far crowns were lighter, so the switch read as the trees darkening and filling in.
- **Fix:** the far version of each near tree now uses a darker duplicate of its own ring material toned like the dense crowns.
  - **After the fix** (`reports/lod-check-20261026-041612-77706`): 1.24% changed against a 0.07% noise floor. Visually the tone now matches, and the remaining difference is leaf density and pattern.
- **Route:** **18/18** after the fix (`reports/route-20261026-041648-77760`).
- **Limits:** these are stills with motion frozen. Continuous manual motion review is still unverified.

## Landform craft pass (2026-10-26)

Changes, checked against `design-reference/mush-concept-1.png`:
- **Massifs:**
  - The cliff line is broken into buttress spurs (~55 m) everywhere, plus columnar flutes (~24 m) inside the 5 m detail patch.
  - Faces are steeper (body transition n 0.16–0.40, was 0.12–0.46).
  - Sharp skyline peaks along narrow crests.
- **Rock pillars:** each is now a fused cluster of four slender needle crags (faceted cross-section that twists with height, uneven ledges, jagged tip, lean), replacing the fat stacked lathe pillar. Same three sites and one draw call.
- **Giant footings:** the old landform is now preserved under each giant's stem and buttress footprint instead of under its cap radius (hero: 198–330 m), which had left an unchanging stepped terrace tower standing behind the stem.
  - The first version (`036ae7d`) preserved only the hero's footprint and raised or lowered six small giants by up to 60.42 m. That departed from the instruction to preserve footings.
  - Corrected: every giant keeps its own narrow, smoothly faded support zone (full within 2.6 stem radii, gone by 4.8, stem radius 0.15 × cap radius). All seven base heights match the ground they stood on at `bd3fcea`.
  - Maximum all-giant footing drift is **0.0 m** (tolerance 0.01 m). This is now a hard check in the prototype report and in the scenic capture (`giant_footing_check`).

Cost:
- **Terrain triangles:** unchanged (91,442 coarse + 51,520 detail patch).
- **Rock spires:** 24,192 triangles, up from 7,872 for the previous pillars (computed from that mesh definition; +16,320).
- **Draw nodes:** unchanged at 88.

Checks:
- All-giant footing drift 0.0 m (7/7); route terrain drift 0.0 m; normals finite.
- Near-vertical coarse vertices: 286 (was 169).
- **Scenic:** all views pass framing and floor checks, plus the footing check. The vista coverage gate still **fails** at 0.0129 (`reports/scenic-20261026-044356-79174`).
- **Route:** **18/18** (`reports/route-20261026-044557-79276`).
- **Visible side effect:** the (−280, −760) giant's original ground sits about 60 m below the new massif there, so it stands in a narrow recess cut into the massif, visible in the overview.

Not rerun or still failing:
- **Benchmark:** not rerun. The p95 17.573 ms failure stands.
- **LOD:** the leaf-density change at 94–96 m and 118–120 m remains.

## Connected environment slice: knoll to lake shore and hero root (2026-10-26)

**Status: traversal validated; art not accepted. The junction seam is fixed; see the junction seam correction below.** Rollback: `git revert` this commit, or `--prototype-scenery=off`.

Geometry (startup-only, `scripts/prototype_scenery.gd`):
- **SliceRoute:** one walking ribbon from the existing route end (72, 26.86, 215) to a documented endpoint 2.5 m before the hero-root collider. It runs 1,488.6 m in 921 samples: a summit loop, two 14 m hairpins, terraces down to the valley floor, then the east lake shore.
  - **Grades:** walking grade at most 14.0°; steepest surface (shoulder) 22.8°.
  - **Turns:** minimum turn radius 8.43 m.
  - **Cross-section:** 3.6 m tread with 2.2 m shoulders.
  - **Collision:** its own collider of 5,520 faces, the same triangles it renders, on layer 1.
  - **Height range:** about −82 m to +34 m.
- **HeroRootCollision:** a StaticBody3D of 432 triangles taken from the hero stem between 6 m below and 12 m above the ground. Only the root stops a walker.
- **Terrain:**
  - A bed is carved under the ribbon, and a second 5 m detail patch covers it (`SliceDetailPatch`).
  - Vegetation keeps its random stream and is filtered off the tread.
  - `far_terrain.gdshader` feathers the clearing's moss tone (a noisy 45 m edge).
  - The far layer still has no colliders.
- **Movement:**
  - The movement-only extension now admits the exact slice corridor.
  - Safe, save and teleport positions still require the original box.
- **Fall guard:**
  - `lineage/entrance48-player-step-proposal02/player.gd` moves its inline `y < -1.5` recovery test into `_fell_below_world()`. The rule is unchanged, the edit is 7 lines and it is the only `lineage/` edit.
  - `scripts/air_capsule_guard.gd` overrides it so that a walker below −1.5 m stays put only when standing on an extension corridor with ribbon support within 1.2 m.
  - Off-corridor or unsupported positions still recover. With no extension installed, the original rule applies.
- **Topology change (PM-authorized):**
  - The old route end is now the slice junction, not an open fall edge.
  - The `route` suite verifies grounded continuation there.
  - It also checks recovery at the junction's exposed side and at the summit loop's outer edge.

Checks, in order. All runs are on the same runtime source; receipt manifests match except for test and runner files.

| Suite | Result | Report |
|---|---|---|
| `junction` (harness-placed; not continuous proof) | 12/12 — route→slice and back on 0 and ±1.2 m lines; supported walk below −1.5 m; stepping off below −1.5 m still recovers | `junction-20261026-060508-86940`, fresh repeat on the committed test file `junction-20261026-073119-98088` (12/12) |
| `endpoint` (harness-placed from 440 m; not continuous proof) | 6/6 — reaches the endpoint, unobstructed approach frame, input contact probe, 60 m return | `endpoint-20261026-070641-94961` |
| `slice` (definitive full out-and-back) | **26/26**, 890 s, exit 0, no leak lines | `slice-20261026-070902-96139` |
| `route` (old route, updated topology assertion) | **22/22** | `route-20261026-072355-96790` |
| `acceptance` | **295/295**, no leak | `acceptance-20261026-062600-89451` |
| `scenic` | **Fails** only the known vista coverage gate (0.0128 < 0.02); framing, floor and all-giant footing (drift 0.0 m, 7/7) pass | `scenic-20261026-073421-99024` |

Full-walk details (`slice-20261026-070902-96139`):
- **Outbound:** clearing → route → junction → whole slice → endpoint: 48,237 ticks, 1,746 m, 100% grounded, no recovery. Largest per-tick drop 0.014 m; camera clearance at least 0.21 m.
- **Contact probe:** forward input from the endpoint is stopped by the hero-root body itself, 0.43 m ahead. The walker ends grounded, on the corridor, with no recovery.
- **Saves:** save and safe positions stay in the original box.
- **Return:** endpoint → knoll junction: 40,981 ticks, 100% grounded, no recovery. The route suite separately covers the clearing ↔ knoll leg.
- **Edges:** Float on the shore ends grounded. Stepping off at the lake side and on both sides of the descent recovers into the original box, and `teleport_safe` onto the slice resolves into the box.

Images (1280×720 runtime captures; inspected):
- `slice-root-approach-day.png`: real walk, 364 m from the hero centre. Path, buttressed root base beside the walker, stem and cap underside.
  - **Proven in-frame:** both root targets project in frame and clear of the avatar. Nothing blocks them: no terrain, and none of the 3,685 prototype instance bounds.
  - **Out of frame:** the cap top is cropped.
- `slice-shore-day.png`: east-shore arrival, real walk. The composition is flat and the lake reads as a dull grey-brown sheet.
- `slice-root-contact-day.png`: contact proof only. It is wall-filling and is not a landmark image.
- `route-20261026-072355-96790/route-overlook-day.png`: shows the junction seam below.
- Wide views: `scenic-20261026-073421-99024/world-overview-day.png`, where the slice reads as one continuous line from the knoll to the hero root, and `rim-overlook-day.png`. The clearing still reads as a square patch.

Costs from the static prototype report (`scenic-20261026-073421-99024`):
- **Terrain:** coarse terrain 91,442 → 83,616 triangles, with the replaced cells moving into the new 32,028-triangle slice patch.
- **Slice ribbon:** 5,520 rendered triangles and 5,520 collision faces.
- **Hero root collider:** 432 triangles.
- **Unchanged:** the existing route at 1,590, the forest carpet at 504,000, and far-layer colliders at 0.
- **Copied trees:** 960,480 → 918,196 triangles built, filtered off the tread; near-crown replacement 18/18.
- **Draw nodes:** 88 → 89 as counted by the report.
- **Prototype-owned colliders:** 3 (route, slice, root).
- **Frame time:** not measured.

Open defects and limits (not fixed):
- **Junction seam (fixed in the junction seam correction below):**
  - The slice's first cross-section is rotated about 1.8° from the route's last one. This leaves a wedge gap in both render and collision on one side: 1–2 cm at 0.5 m out, about 3 cm at the 1.2 m walking line, and 12 cm at the 3.75 m shoulder edge (`terrain-probe-20261026-073005-seam`).
  - It shows as a green crack in the knoll overlook.
  - The earlier "no gaps" junction note used 5 cm rays and missed it.
  - All walks across the junction pass.
- **Return leg:** ends at the knoll junction, not the clearing.
- **Intermittent exit leak:** "resources still in use at exit" (scenic `052059`, earlier acceptance `015518`). Root cause not established; it did not recur in these runs.
- **Art not accepted:** shore view flat; pale smooth stem; low-poly crowns; vista coverage gate fails.
- **Performance:**
  - Benchmark not rerun; the p95 17.573 ms failure stands.
  - GPU time unmeasured.
  - The slice adds geometry and colliders.
- **LOD:** the leaf-density change at 94–96 m and 118–120 m remains.
- **Manual evidence:** motion, feel, audio and device are not verified.

Retained failed evidence:
- **Slice:**
  - `052936`: fixture walked to the wrong target.
  - `053046`: stuck at the junction; existing-route intrusion regression, since fixed.
  - `055125`: 4–6 cm join lip.
  - `055625`: recovered by the `y < -1.5` guard; its root frame was mislabelled.
  - `060755`: 23/25, stuck against the root.
  - `063323`: 25/25 under the since-rejected stall-zone rule. Not root-arrival evidence.
- **Route:** `063025`: 17/18, open-end assertion before the topology decision.
- **Junction:** `060141`: start-up teleport overlap and the guard.
- **Endpoint:**
  - `065218` and `065446`: unusable approach frames, taken under the cap.
  - `065731`: fixture tick cap.
  - `070057`: the hero's own stem counted as a blocker.

## Runner: pre-launch parse check and fail-fast (2026-10-26)

Two junction runs never executed their test, because of duplicate-variable parse errors in the fixture:
- **`junction-20261026-074518-1656`:** waited out the full 600 s deadline.
- **`junction-20261026-075538-3393`:** my outer `timeout 580` killed the runner first and left its engine (PID 3402) orphaned. I reaped that process; no receipt was written.

An unpiped `--check-only` printed the parse error but **exited 0**, so its exit status alone cannot gate a run.

`tools/verify.py` now does two things:
- **Pre-launch check:** for the prototype capture suites (slice, junction, endpoint, route, scenic) it runs `--check-only` on the fixture and classifies the output into `preflight.log`. A nonzero exit or a startup failure stops the run before launch.
- **Fail-fast:** during any run it watches the log for the same startup failures, stops its own engine process after a 2 s flush and keeps the log.

Startup failures are `SCRIPT ERROR: Parse Error` and `ERROR: Failed to load script`. Any `ERROR` line already failed a run, so no outcome changes; only the wait is shorter.

Checks:
- Runner unit tests pass.
- The classifier flags both failed logs above and neither passing log (slice `070902`, acceptance `062600`).
- The pre-launch check passes on the slice, route and scenic fixtures.


## Junction seam correction (2026-10-26)

**Cause:** each ribbon ring is square to its neighbouring samples. The existing route's last ring is square to its final segment. The slice's first ring followed the slice curve's first segment, which bends 1.795° toward the summit loop, and that left a wedge between the two rings.

**Fix:**
- `scripts/prototype_route.gd` gains an optional `start_direction` that sets only the first ring's travel direction. It is validated and refused beyond 10° from the curve. The bend is reported.
- The slice passes `route.get_end_direction()`, so the two rings coincide: same centre, height, sideways axis, widths and shoulder drop.
- **Unchanged:** path centres, anchors, length (1,488.55 m), collision faces (5,520), minimum turn radius (8.43 m), corridor widths and the existing route (parameter absent).

**New focused regression** (junction suite): rays every 0.1 m across the full width and every 5 mm along ±25 cm of the junction. It requires no gap over 5 mm, no overlap over 1 cm and no height step over 1 cm. The render uses the same triangles as the collision.

| Measure | Unfixed (`junction-20261026-080739-5687`) | Fixed (`junction-20261026-081037-6390`) |
|---|---|---|
| Collision/render gap | 12.5 cm at −3.95 m (**FAIL**) | 0 |
| Overlap | 12.5 cm at +3.85 m | 0 |
| Largest height step | 2.4 cm | 1.2 mm |
| Junction suite | — | **13/13** |

- **Independent 1 cm probe** (`terrain-probe-20261026-081400-seam-fixed`): no gap anywhere within ±3.75 m, against up to 12 cm before. The 0.5 m summit map has no holes between the two ribbons.
- **Affected regressions on the fixed geometry:**
  - `route` 22/22 (`route-20261026-081428-7507`).
  - Full out-and-back `slice` 26/26 (`slice-20261026-081725-8264`; same ticks and distance as before).
  - `acceptance` 295/295 (`acceptance-20261026-083218-10003`).
  - No source changes and no leak lines.
- **Pixels:** the green crack in `route-overlook-day.png` (`route-20261026-072355-96790`) is gone at the same pose (`route-20261026-081428-7507/route-overlook-day.png`).

Rollback: `git revert` this commit.

## Path material: worn track with moss shoulders (2026-10-26)

**Status: material-only pass, pending PM review; art not accepted.** Rollback: `git revert` this commit.

**Change:**
- The two walking ribbons (the existing route and the slice) share a new prototype shader, `assets/world/prototype_path.gdshader`. It replaces the uniform orange earth material.
- **Track:** a narrow worn-earth track meanders on the tread, about 1.5–2.3 m wide with a ragged edge and a few bare patches. It fades through trampled grass into moss shoulders and embankment skirts.
- **Moss:** reproduces the far terrain's own moss branch (clearing feather, near detail, macro tone, damp valley).
- **Seamless join:** patterns use world XZ, so the two ribbons continue through the junction without a visible restart.
- **Earth:** desaturated packed earth at about the old brightness.
- **Shoulder shading:** the shoulders' shading normal leans toward up, so the verge lights like the neighbouring ground instead of showing the tread-edge crease. This is shading only.
- **Unchanged:** ribbon geometry, collision, walkable and safe corridor widths, anchors and the clearing.

**Evidence:**
- **Matched pairs** (`path-pairs-20261026-084112-11808`). A new diagnostic suite, `path-pairs`, is harness-placed at the poses recorded by the definitive walks. Each pose is captured with the previous material, rebuilt exactly, then with the new one, in the same process and frame. Only the ribbon material differs. All poses are within 1 cm of the recorded ones.
- **Rejected first look:** the first pass (`path-pairs-20261026-083846-11185`) made the earth nearly black (about 34, 13, 5 sRGB) and showed the tread/shoulder crease as a hard green edge. It is superseded.

Lower frame (y ≥ 400, avatar excluded):

| Pose | Earth share before → after | Green share before → after |
|---|---|---|
| Root approach (`slice-root-approach-day` pose) | 78% → 51% | 19% → 42% |
| East shore (`slice-shore-day` pose) | 92% → 26% | 8% → 71% |
| Knoll overlook (`route-overlook-day` pose) | 91% → 32% | 7% → 44% |

- **Scenic** (`scenic-20261026-084237-12189`):
  - Fails only the known vista coverage gate (0.0130 < 0.02).
  - Footing drift 0.0 m (7/7).
  - Draw nodes, triangle counts and colliders unchanged.
  - No error or leak lines.
  - The clearing views are unchanged.
- **Not rerun, by PM decision:** the traversal, route and acceptance suites. The change is material-only and movement and collision are unchanged. The last runs on identical geometry are slice 26/26 `081725`, route 22/22 `081428` and acceptance 295/295 `083218`.

**Limits:**
- **Root approach:** a soft, fairly straight boundary remains where the track meets the sunlit verge. Near the camera the track is broad and smooth, because Rock01 is magnified there.
- **Overview:** from above, the path is less visible than the old orange line.
- **Not done:** no ground-cover meshes, pebbles or normal map.
- **Not measured:** frame time and GPU cost of the shader. It adds about 8 texture fetches per ribbon fragment.
- **Still open:** the benchmark p95 failure (17.573 ms) stands, the LOD density change remains, and the art is not accepted.

## Corridor foreground: ground plants and near-corridor trees (2026-10-26)

**Status: local improvement, pending; scene art not accepted.** Visual only. Rollback: `git revert` this commit.

**Where:** one limited stretch, the east shore and lower root approach (z −240 to −440), in `scripts/prototype_scenery.gd`.

**Large forest-carpet blobs** (the low-poly clumps) are set aside non-destructively: kept, hidden, in `CorridorReplacedCarpet`.
- **Within 60 m (body) of the path:** 17 clumps, replaced by open ground with plants.
- **Centre within 125 m:** 15 more, the right-side walls seen in the root-offset, root-approach and bank-close-up views.
  - They were identified per view by owner, position, size and screen box (`understory-pairs-20261026-093700-26497`).
  - They are replaced by 28 copied native trees: bent trunks, ring crowns, grounded on the rendered terrain.
  - Groups are sized to each clump: one tree, two, or three lower ones.
- **Untouched:** clumps farther out stay as backdrop (visible ones are 166–306 m away).

**Ground plants:** 42 composed groups made from the clearing's own understory meshes, at creature-scale heights.
- **Fern-and-fungus groups:** fern crowns plus a fairy-mushroom cluster and moss.
- **Mushroom-and-moss rings and flower drifts.**
- **Fern materials:** darker duplicates of the clearing leaf materials. The originals are untouched, and the duplicates follow their night state.
- **Clearance:** no plant within its distance of the path centre (closest 3.03 m; the walking surface edge is at 1.8 m).
- **Attachment:** each mesh floor sits 2 cm below the lowest rendered surface under its footprint.
  - Independent check: 2,332 transformed bottom corners, 17 more than 10 cm above the ground, worst 0.289 m.

**Costs:**
- **Ground plants:** 583 instances, 142,330 triangles, 26 nodes.
- **Trees:** 145,968 triangles, 6 nodes. The dense near crowns were tried and dropped; they built 572,880 triangles.
- **Colliders and shadows:** none added.
- **Draw nodes:** 89 → 121.
- **Root-approach view:** 602k → 855k primitives, 78 → 95 draw calls.
- **Root-offset view:** 557k → 816k primitives, 74 → 93 draw calls.
- **Copied trees elsewhere:** unchanged (918,196 triangles); their node construction now goes through a shared helper.

**Evidence:**
- **Before/after pairs:** `understory-pairs` suite, harness-placed, five poses, same pose and frame (`understory-pairs-20261026-094105-27928`). These are the root approach, shore, shore offset, root offset and a bank close-up.
- **Frame time at those poses** (1280×720, uncapped, fixed physics step, 30 warm-up + 180 samples, engine drew all 180; not the route benchmark):

| View | Wall p50, old → new look (ms) |
|---|---|
| Root approach | 8.466 → 8.325 |
| Root offset | 8.483 → 8.325 |
| Shore | 14.234 → 14.189 |

  GPU time is unavailable on this driver.
- **Scenic** (`scenic-20261026-094206-28006`): fails only the known vista coverage gate (0.0129).
  - Slice and route geometry, collision and widths unchanged.
  - Owned colliders stay at 3; far-layer colliders 0; shadow casters 0.
  - Giant footing drift 0.0 (7/7).
- **Not rerun:** the traversal suites (visual only).
- **Route benchmark** `benchmark-20261026-091430-19224` stays **failed**: p95 18.086 ms, p99 22.728 ms.

**Rejected iterations, retained:**
- `understory-pairs` 085647–091126: plants too small or too sparse, pale shards, one floating leaf. `090741` and `091017` exceeded the triangle budget.
- 092641–092833: too sparse, or the ferns could not be seen.
- 093938: dense crowns.

**Limitations:**
- **Ferns** barely read against the moss.
- **Ground plants** are sparse and mushroom-led.
- **Groves** are lighter than the mass they replace.
- **Backdrop clumps** beyond 125 m remain.
- **LOD:** leaf density still visibly changes at 94–96 m and 118–120 m.
- **Not checked:** night appearance of the corridor; any manual or device checks.

## Cliff rock readability (2026-10-26)

**Status: local material improvement; the sawtooth silhouette is unchanged; scene art not accepted.** Rollback: `git revert` this commit.

**Owner:** a camera-ray pick against every prototype mesh's triangles (`rock-pairs` suite) hit **`CliffDetailPatch`** for every near-black pixel in the root-approach and root-offset views. That is the massif's 5 m detail terrain, about 390–460 m away near (537–571, 3–99, −631 to −647).
- **First guess retracted:** I first attributed the black face to the needle crags. Changing those had no effect (`rock-pairs-20261026-095041-28575`) and was reverted.

**Cause:**
- **Albedo collapse:** at 300–600 m the terrain shader's far texture pair multiplies two dark Rock01 layers, giving rock albedo of about 0.03–0.05.
- **Facing:** these faces are turned away from the sun.
- **Tonemap:** the tonemap crushes the result to near black.

**Change** (`assets/world/far_terrain.gdshader`; values in `scripts/prototype_scenery.gd`): new terrain uniforms, applied only inside the cliff patch's region.
- **Mask:** an irregular ~250 m fade inside its edges, weighted by rockiness. Outside the region, and at zero strengths, rendering is exactly as before.
- **`rock_albedo_lift` 2.2:** restores a natural rock range.
- **`rock_breakup` 1.0:** neutral mineral tone, isotropic two-scale mottling, broken strata and ledge lichen.
- **`rock_relief` 0.5:** procedural normal variation.
- **`rock_fill` 1.0:** daylight sky-bounce on faces turned from the sun. It is scaled by albedo, fogged, and fades to 5% at night.
- **Unchanged:** geometry, collision, route, anchors, giants, global lighting and the haze.

**Evidence** (`rock-pairs-20261026-100918-30016`): before (neutral defaults) and after in the same frame, at three views — root approach, root offset and a rock-offset view — in day, night and rain.
- **Shaded face, mean luma (0–255):**
  - Root offset: day 13.4 → 28.8; night 5.2 → 13.1, moonlit and not glowing; rain 14.1 → 29.3.
  - Root approach: day 19.6 → 33.7.
- **Colour:** saturation 0.553 → 0.320, so no bark-brown.
- **Streaks:** vertical-gradient anisotropy 1.97 → 1.67, below the untreated value. The fluted geometry keeps some vertical bias.
- **Control:** a distant hazed massif outside the region is identical.
- **Rejected iterations, retained:** rock-pairs `095237` and `095355` (too dark); `095457` (warm vertical ribs read as bark).

**Boundary:** the overview's tone gap between the hero-side massif and the left massifs predates this pass (105.1 vs 85.9 luma in the untreated `scenic-20261026-094206-28006`). The treatment changes the hero-side massif's overview tone by only +1.7 luma (`scenic-20261026-101031-30105`); the untreated massifs are pixel-identical. No regional seam is visible.

**Scenic** (`scenic-20261026-101031-30105`): fails only the known vista coverage gate (0.0130). Terrain triangles, slice and route geometry, collision, root collider, colliders, shadow casters and draw nodes are unchanged. Footing drift is 0.0 (7/7).

**Limitations, retained:**
- **Silhouette:** the sawtooth crests and vertical flutes are geometry and remain.
- **Strata:** faint at 400+ m.
- **Shaded faces:** deliberately still dark.
- **Shader cost:** a few more noise lookups per terrain fragment inside the region; frame time not measured.
- **Benchmark not rerun:** the route benchmark still **fails** (p95 18.086 ms).
- **Still open:** the vista coverage gate and the leaf-density change at 94–96 m and 118–120 m. Manual and device checks are not done, and the overall art is not accepted.

## Hero stem organic finish (2026-10-26)

**Status: modest local improvement; scene art not accepted.** Material only. Rollback: `git revert` this commit.

**Change** (`assets/world/far_canopy.gdshader`, stem branch; values in `scripts/prototype_scenery.gd`): new `stem_focus` and `stem_organic` uniforms on the shared `CanopyStems` material.
- **Scope:** only within 200 m of the hero base (the nearest other giant is about 395 m away). At strength 0 every stem renders exactly as before.
- **Tone:** soft modulation at several metres, scaled equally vertically and horizontally so it doesn't band.
- **Fibre:** very low-contrast, fading with distance.
- **Finish:** matte (roughness 1.0, specular 0.02).
- **Surface:** gentle normal undulation at two scales.
- **Ground contact:** a soil/moss blend at the root.
- **Unchanged:** mesh, silhouette, footings, collision, route, anchors, global lighting, and the cap and collar glow.

**Evidence** (`stem-pairs` suite, `stem-pairs-20261026-102434-31432`): before (strength 0) and after in the same frame, at the root approach and the rim-overlook camera, day and night.

| Stem region | Brightness (luma), before → after | Vertical-banding ratio |
|---|---|---|
| Root approach | 126.1 → 120.4 | 3.85 → 3.02 |
| Overlook | 143.5 → 139.4 | 4.13 → 3.66 |

- **Control:** the second giant's stem in the same frame is unchanged.
- **Night:** dimmer, with no glow added.

**Timing** (1280×720, full art, uncapped, fixed step, 30 warm-up + 180 samples, all drawn; GPU time unavailable on this Metal driver; not the route benchmark):

| View | Wall p50 / p95 (ms), before → after |
|---|---|
| Root approach | 8.308 / 9.945 → 8.314 / 10.208 |
| Overlook | 8.063 / 9.570 → 8.287 / 9.705 |

Earlier runs measured p50 differences of +0.015 to +0.077 ms, so the cost is at most about 0.2 ms; this method cannot resolve it further. Primitives and draws are identical.

**Scenic** (`scenic-20261026-102517-31483`): fails only the known vista coverage gate (0.0130). Footing drift 0.0 (7/7), and geometry and collision are unchanged.

**Limitations:**
- **Subtle at overlook distance:** the flutes and buttress grooves are geometry.
- **Not the references' look:** no luminous veining.
- **Not captured:** rain.
- **Still open:** the route benchmark **fails** (p95 18.086 ms), the vista gate fails, and leaf density visibly changes at 94–96 m and 118–120 m.

## Atmosphere: cooler layered distance and blue sky (2026-10-26)

**Status: local improvement; scene art not accepted.** This is a prototype-only lighting change. Rollback: `git revert` this commit.

**Change** (`scripts/prototype_scenery.gd`, `apply_look`, which runs only with the prototype on): new `DEPTH_LOOK` day endpoints.
- **Sun:** `ffc07e` → `ffbc72`.
- **Fog colour:** `a2b3d4` → `8ea4d4`.
- **Lake reflection:** `f2b08e` → `c2b4d6`.
- **Sky top:** `41529f` → `3d74c8`.
- **Sky horizon:** `f4c49a` → `f0dcbc`.
- **Unchanged:** ambient, night and rain endpoints, exposure, fog density and distances, and geometry. With the prototype off, nothing runs.

**Sky cause:** the live sky is `lineage/living-scenery37-proposal01/drifting-clouds37.gdshader`, which computes `mix(horizon, top, pow(height, 0.45))`. At 10–30° elevation, about half of every pixel is the horizon colour, so a peach horizon over a violet top read as lavender.
- **Fix:** a pale cream horizon under a clear blue top.
- **No lineage edit:** the same material and shader objects are kept.

**Evidence** (`look-pairs-20261026-104548-33253`: before (previous look) and after in the same frame; root approach, shore and rim overlook by day; root approach and overlook at night):

| Measure | Before → after |
|---|---|
| Visible sky lavender index ((R+B)/2 − G) | +16 to +27 → +7 to +11 |
| Visible sky blue index (B − R) | −10 to +11 → +18 to +42 |
| Horizon bands | stay warm (blue −22 to −3) |
| Overlook mid massif | L143, warmth −16 → L132, warmth −28 |
| Lake warmth | +40 / +64 → −3 |

- **Foreground:** within 1–2 luma.
- **Night:** 0.08% of pixels change.
- **Timing** (1280×720, full art, uncapped, fixed step, 30 warm-up + 180 samples, all drawn; GPU time unavailable; not the route benchmark): wall p50 8.42 → 8.34 ms (root approach), 15.34 → 15.55 (shore), 8.42 → 8.30 (overlook). That is within noise; primitives and draws are identical.

**Rejected first version, retained** (`look-pairs-20261026-103600-32580` and `scenic-20261026-103711-32659`): a cooler ambient darkened and cooled the shaded clearing (home 71 → 66 luma, warmth +31 → +23).

**Scenic** (`scenic-20261026-104658-33335`): fails only the known vista coverage gate (0.0128). Footing drift 0.0 (7/7), and geometry and collision are unchanged.

**Limitations:**
- **Sky:** it reads pale, a soft daytime blue rather than the references' golden-hour gradient, and the warm horizon is a thin band.
- **Prototype-on clearing:** shifts brighter and cooler through visible sky and sky reflections (home 71 → 74 luma, warmth +31 → +25). The house and windows keep their warmth.
- **Rain:** blends from the new day colours and is bluer.
- **Not added:** mist layers.
- **Still open:** the route benchmark **fails** (p95 18.086 ms), the vista gate fails, the LOD density change is open, and the full-scene art is not accepted.

## Near-crown LOD: dithered crossfade (2026-10-26)

**Status: local transition improvement; not a performance fix.** The full-art benchmark still **fails**. Rollback: `git revert` this commit.

**Finding:** the original copied-tree LOD did more than change leaf density. The near (dense) crown node used range end 100 m and the far (ring) node range begin 100 m, each with a 12 m hysteresis margin. Between about 98 and 118 m from a batch's centre, **both LODs were culled and the crowns vanished.**
- **The documented "pops":** at 94–96 m and 118–120 m they were the two edges of that gap.
- **Physical walk:** the target tree showed bare trunks at 87–89 m from the tree, because the swap followed batch distance, not tree distance.

**Fix:**
- **Crossfade** (`assets/world/prototype_leaf.gdshader`): a per-tree dithered crossfade over 96–116 m of camera distance.
  - Dense crowns keep the pixels whose screen dither lies below the tree's dense share; the ring crown of the same tree keeps the rest, so coverage is exactly complementary.
  - The shader's new lod-fade uniforms (`lod_fade_start`, `lod_fade_end`, `lod_fade_role`) are off (0) by default.
- **Node ranges** (`scripts/prototype_scenery.gd`, `set_lod_crossfade`): no hysteresis. Each near node is drawn to 116 m plus its radius and each far node from 96 m minus its radius, where the radius is the farthest crown origin from the node's AABB centre (26.8–69.7 m).
- **Isolation:** the far LOD gets its own duplicate material, so corridor trees, which draw the far material at every distance, are unaffected.
- **Unchanged:** near shapes inside 96 m, triangles (918,196, 93 crowns) and draw nodes.

**Motion evidence** (`lod-check` v2, `lod-check-20261026-112634-36076`; same runtime source, with later test-tool edits only). Both states run in one process, and every step re-renders the paused pose with the near or far LOD nodes hidden, to get the dense share and total crown coverage.
- **Harness-driven:** the review camera moves 130 → 76 → 130 m in 0.5 m steps.
- **Physical:** the character walks the route with real analog move input through CharacterBody physics, toward one tree and back away from it. The follow camera's aim is set by the harness.
- **Original:** pops (share jumps 0.47–0.76) and crownless gaps in 3 of 3 sequences.
- **Crossfade:** largest step 0.061–0.093 and no gaps. Zero steps were excluded for terrain occlusion, and both walks crossed 88–124 m with no recovery.
- **Superseded fixture iterations, retained:**
  - `110017`: motion swamped the detector.
  - `110555`: the coverage jump flagged a camera clip.
  - `111205`: its validity floor could hide gaps; an explicit gap check was added.
  - `112007`: the walk camera pitch pressed the camera into a bank.

**Cost:**
- **Benchmark** (`benchmark-20261026-113256-36371`): **fails** at p95 19.834 ms and p99 24.402 ms (8,517 frames, 2 loops, 0 stalls, render CPU p95 2.609 ms, GPU timing unavailable). The previous run, `091430`, measured 18.086 / 22.728 ms. **Cause not established.**
- **Controlled LOD-only comparison** (`lod-cost` suite, `lod-cost-20261026-113942-36986`):
  - **Setup:** same process, 1920×1080, night and rain, two rounds of swap/crossfade/crossfade/swap, 20 warm-up + 90 samples, VSync off while sampling.
  - **Timing:** crossfade minus swap ranged from −0.31 to +0.11 ms across four route poses, the rim overlook and a transition view, while individual measurements vary by up to 2.6 ms.
  - **Primitives:** unchanged at 4 of 6 poses; +171,120 at route-west and +21,620 at the transition view.
  - **Limit:** both states use the same compiled shader, so the cost of the shader's discard path itself is not isolated.

**Scenic** (`scenic-20261026-114143-37485`): fails only the known vista gate (0.0129).
- Canopy and clipped metrics are unchanged.
- Rim overlook, cliff detail, landform side and world overview differ by 0.06% or less.
- Ground path differs by 1.8%, within its run-to-run range of 1.3–5.8%.

**Limitations:**
- **Stipple:** the dither shows as a stipple inside the 20 m band during motion; there is no anti-aliasing.
- **Not verified:** live display motion.
- **Still open:** the benchmark failure, the vista gate and full-scene art acceptance.

## Opposite-shore groves (2026-10-26)

**Status: local improvement; scene art not accepted.** Visual only. Rollback: `git revert` this commit.

**Target:** the pale low-poly `ForestCarpet` blob row on the lake's far bank, seen from the east-shore walk.
- **Inventory** (`shore-pairs-20261026-114728-38153`): blobs per view at the shore pose, the rim overlook and an offset east-shore view.
- **Belt:** clumps with origin y −82.5 to −69 (within ~13 m of lake level), within 360 m of the lake centre, and west of x 300. That is 103 clumps, rendered 12–59 m wide and 9–29 m tall.

**Change** (`scripts/prototype_scenery.gd`, `_add_shore_groves`):
- **Removed from carpet:** the belt clumps leave the carpet multimeshes. They are kept in `ShoreBeltClumps` as the groves' far LOD, drawn beyond 650 m.
- **Groves:** each clump becomes 1–2 low, wide shrub masses made from the copied trees' broken ring-crown mesh, at 60–80% of its rendered width.
- **Trees:** widest clumps first and within a fixed 400,000-triangle budget, copied native trees rise from the shrubs: one per clump, two for clumps 40 m or wider. Each keeps its trunk parts and three crowns scaled 1.6×.
- **Result:** 164 shrubs, 76 trees, 396,848 triangles and 2 nodes, drawn to 700 m.
- **Distant views:** they keep the clumps.

**Evidence** (`shore-pairs-20261026-115514-39340`: before and after in the same frame at the shore, overlook and shore-offset views):
- **Shore and offset views:** the waterline blob row becomes a continuous ragged forest edge of trunks and broken crowns over a shrub layer.
- **Overlook:** only the lower-left bank changes. Its remaining mid-ground blobs are 690–870 m away, beyond the belt.

**Cost:**
- **Primitives:** +380k at shore and offset (+9%), +380k at the overlook (+39%). Draw calls +1; draw nodes 121 → 124.
- **Timing:** per-view wall p50 rose 1.0–2.1 ms after sequential before/after sampling. Render CPU p50 was about the same, and GPU time is unavailable.
- **Noise:** another workload shared the machine, and the same shore view's before p50 ranged from 29.7 to 40.9 ms across runs. These timings are **not** a reliable cost measure.

**Scenic** (`scenic-20261026-115653-39655`): fails only the known vista gate (0.0128).
- Canopy and clipped metrics are unchanged.
- Footing drift is 0.0 (7/7), and geometry and collision are unchanged.

**Rejected iterations, retained:**
- `114931`: over budget at 561k and 18 nodes; the thin top-crown trees lost the bank's mass.
- `115219`: 15 nodes, and the band was still thin.
- `115355`: groves sized from the clump scale factor instead of the rendered size, about half-size.

**Limitations:**
- **Height:** the new band is lower than the blobs it replaces.
- **Contrast:** the pale blobs further up the slope, outside the belt, now contrast with the darker waterline forest.
- **Far view:** the clumps return beyond 650–700 m.
- **Not checked:** night and rain views of the groves.
- **Still open:** the route benchmark (p95 19.834 ms) and the vista gate. Full-scene art is not accepted.

## Opposite-shore groves: cost reduction (2026-10-26)

**Status: local improvement; scene art not accepted.** This supersedes the grove cost, and the 650 m clump far LOD, in the opposite-shore groves section above. Rollback: `git revert` this commit.

**Cost source:** the 164 shrubs and 228 tree crowns all used the copied trees' 940-triangle ring-crown leaf mesh, 368k of the 397k triangles. The groves are never closer than about 210 m to a walkable path. At that distance a 0.5 m leaf card covers about 1.4 px, so only the crown outline reads.

**Change** (`scripts/prototype_scenery.gd`, `_simplified_crown`):
- **Simplified crown:** a decimated copy of the crown mesh for the belt only. The 235 connected leaf cards are found by shared corner positions (the source mesh is non-indexed), every fourth card is kept, and each is scaled 1.7× about its own centre to preserve the crown's coverage and outline: 940 → 232 triangles.
- **Untouched:** the source mesh and every other tree.
- **Population unchanged:** the same 164 shrubs and 76 trees from the same random stream and selection, still selected against the full-detail 400k budget. The built triangles must stay within 150,000.
- **No far swap:** the groves draw to 1,700 m, the carpet's own range, and the belt clumps stay hidden while the groves are on, so there is no transition to pop or leave a gap.

**Measured** (`shore-pairs-20261026-120426-40660`: before and after in the same frame; day at the shore, overlook and offset views; night and rain at the shore and overlook):

| Measure | Full-detail groves (`115514`) | Simplified (`120426`) |
|---|---|---|
| Built triangles | 396,848 | 119,312 (−70%) |
| Shore view primitives | +379,544 | +102,008 |
| Overlook primitives | +379,544 | +102,008 |
| Offset view primitives | +379,544 | +102,008 |

- **Draw calls:** +1 in each view; 2 nodes.
- **Timing:** wall p50 changes of −1.3 to +1.4 ms are within noise under a shared-machine workload. GPU time is unavailable.

**Image tradeoff** (zoomed three-way comparison of blobs, full detail and simplified):
- **Shore band:** trunks and the ragged forest edge are preserved.
- **Overlook lower left:** the grove reads slightly sparser, with larger leaf cards and a little more ground showing.
- **Rain:** matches day.
- **Night:** the groves render clearly darker than the blobs did. The carpet uses a pale-cyan night tint, the copied-tree leaf material the clearing's darker night palette. The band reads as dark forest, not missing.

**Scenic** (`scenic-20261026-120702-41036`): fails only the known vista gate (0.0128).
- Canopy and clipped metrics are unchanged.
- In the world overview the groves appear as a darker textured patch on the west bank, with no hole or abrupt edge.
- Geometry and collision are unchanged; footing drift 0.0.

**Failed run, retained:** `120236`. A script error occurred because the crown mesh is non-indexed; it was fixed before the measured run.

**Limitations:**
- **Night:** a darker band beside the pale-cyan blobs.
- **Overlook:** slightly sparser lower-left grove.
- **Still open:** the route benchmark (p95 19.834 ms) and the vista gate. Full-scene art is not accepted.
