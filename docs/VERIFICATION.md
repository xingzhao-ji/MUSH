# Verification of the clean source

October 11, 2026. The portable development copy imports and passes its fresh gameplay, environment, material-parity and still-capture checks. **The sustained Mac frame-time budget remains failed.** No GitHub upload or release acceptance is claimed here. Each result is bound to its recorded source fingerprint; later source changes require the relevant checks again.

The checks use Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), Forward+/Metal, an Apple M4 Pro Mac with 48 GiB RAM, and Dummy audio. Engine SHA256: `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

## Fresh checks

| Check | Result | Scope |
| --- | --- | --- |
| Clean import | Passed | One generated test UID was recorded; no imported engine/cache files belong in Git. |
| Gameplay acceptance | **295/295 assertions, 15/15 scenarios** | Real Main startup, physics, gameplay and save/crash-recovery tests; automated input, not manual controls. |
| Ground material parity | **32/32 checks and 14,867 native comparisons**, before and after cleanup | Live startup, six appearance/lifecycle phases, material/texture aliases, repeated refresh and 32-entry capacity. |
| Environment contract | **133/133 checks** | The stale SSR expectation was corrected to the retained production setting, disabled. This does not enable SSR or prove mobile rendering performance. |
| Still captures | **4/4 images**, 960 × 960, full PNG decode/CRC and pixel/hash readback | Day, night and entrance views. The receipt distinguishes paused World motion from continuing environmental shader motion. Art and motion remain unaccepted. |

Successful suites recorded no source changes during execution; import separately admitted its new UID. The runner rejects optimized Python execution that disables assertions, checks benchmark route completion/resolution, and keeps evidence in ignored `reports/`. Four runner tests also pass: failed native execution, failed assertions, source mutation and compression failure still leave an honest receipt. Preservation is now checked even after a failed suite. Full reports remain local; the compact [verification summary](verification-summary.json) records their hashes and paths.

## Frame-time gate

The unchanged limits are **p95 <= 16.7 ms** and **p99 <= 33.3 ms**. All three 120-second night/rain routes completed two loops with zero stalls at 1920 × 1080 output. Every run exceeded p95; their failures remain failed.

| Run | Timing condition | Frames | p95 | p99 | Result |
| --- | --- | ---: | ---: | ---: | --- |
| 03:07 | Default VSync | 7,133 | 18.768 ms | 21.097 ms | Failed p95 |
| 03:12 | Uncapped diagnostic | 9,285 | 17.903 ms | 20.770 ms | Failed p95 |
| 03:15 | Matched window, default VSync | 6,808 | 23.716 ms | 27.853 ms | Failed p95 |

Percentiles were independently recomputed from each complete CSV. These measure application callback intervals, not display presentation. GPU timing is unavailable. Source/render settings and window conditions are in each receipt; the rows are not a controlled before/after speedup comparison. The historical249 pass does not override these fresh failures.

Short 30-second script/native profiling runs are diagnostics only, include instrumentation overhead and completed no route loop. Later script-profiler samples are mostly around 1 ms, with startup spikes separately present. That suggests script micro-optimization alone is unlikely to explain the whole interval, but it does not identify or measure a GPU bottleneck. Native sampling reported a roughly 1.9 GB physical footprint; the engine's roughly 140 MB static-memory monitor is a different metric. GPU/display timing and sustained thermal behavior remain unmeasured.

The material-forwarding change removes a temporary O(V) values array, with V <= 32, while preserving O(VU) forwarding work. Native parity passes. **No measured frame-rate improvement is claimed.** Further performance work must preserve scenery and use fresh measurements.

## Storage verification

Authorized archive cleanup removed 25 redundant extracted apps only after validating retained ZIP payloads. All archives, accepted apps, source generations, unique assets and saves remain available.

842 large JSON reports were losslessly filesystem-compressed. All 842 logical payload SHA256 hashes were independently reread successfully; allocated report bytes fell by **8,447,594,496 bytes**. Available space was **10,547,183,616 bytes before** and **18,721,767,424 bytes at the later recorded sample**: approximately 10.547 → 18.722 GB, or 9.82 → 17.44 GiB. This observed free-space difference is not exact exclusive attribution because APFS sharing, delayed accounting and other activity affect it.

The unchanged post-cleanup guard passed 628 strict records and verified all 230 original243 source payloads. The protected metadata audit recorded ten ctime-only changes outside cleanup targets with unproved cause; contents were subsequently verified, and historical metadata equivalence is not claimed. The clean repository's measured Git pack is **36,685 KiB / 35.83 MiB**; this excludes ignored caches/builds/reports and is not game memory usage or a remote-upload measurement.

## Open acceptance

Physical iPhone/iPad/Android tests, an installable IPA, exported-app performance, live listening, manual movement/camera comfort, continuous motion quality and final art/reference fidelity remain pending. Near-cut paving contact coverage, the aggregate full-route contact gate, thick dark slab fronts, broad moss gaps, night readability, shadow/contact quality and water joins remain open. The character remains provisional.

Local receipts are under `reports/`; archive cleanup receipts are under the retained `mobile-transition/review/storage-cleanup253/` archive. `SOURCE_MANIFEST.json` binds the portable tracked payload (excluding itself). Local Git commits retain the baseline and the narrow allocation change for rollback; remote verification is pending.
