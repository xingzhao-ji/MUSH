# Verification of the clean source

October 11, 2026. The portable development copy imports and passes its fresh gameplay, environment, material-parity and still-capture checks. **The current mac062 app fails p95; the prior lower-joint source pass and earlier failures remain recorded.** The as-is GitHub baseline upload is verified; whole-game release acceptance remains open. Each result is bound to its recorded source fingerprint; later source changes require the relevant checks again.

The checks use Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), Forward+/Metal, an Apple M4 Pro Mac with 48 GiB RAM, and Dummy audio. Engine SHA256: `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

## Fresh checks

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
