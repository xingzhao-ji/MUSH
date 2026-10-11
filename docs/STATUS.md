# Development status

This is experimental 0.6.0 source derived from the combined243 checkpoint, curated into a portable repository. It preserves the paving preview, safe placement/controller work, visual paw correction, shared environment and refreshed audio. Ordinary development windows accept input and use a separate `MUSH-dev` profile. The local archive's 0.5.7 app remains recommended and 0.5.5 remains rollback; this source copy does not replace those apps.

Fresh results for this exact repository belong in [VERIFICATION.md](VERIFICATION.md). Historical results below describe their original checkpoints and are not automatically transferred to changed source.

| Area | Evidence and remaining work |
| --- | --- |
| Gameplay | Combined243 passed 295 original assertions across 15 scenarios with isolated automation input. Re-run the portable source after refactoring. |
| Paving and collisions | Startup binding/rollback trials each passed 13 checks, including a 59-tick route with 16 moving roof contacts. Near-cut contact coverage and the aggregate full-route coverage gate remain open. |
| Performance | Checkpoint249 completed a 120-second Mac night/rain source route: p95 16.282 ms, p99 18.464 ms, two loops and no stalls. This is not a comparative optimization gain, GPU/presentation timing, thermal, export or phone result. |
| Visuals | Thick dark paving fronts, wide moss gaps, night entrance readability, shadow/contact quality, scenery/reference fidelity and water joins remain under review. The character is provisional. |
| Motion and controls | Scripted movement coverage exists. Manual movement/camera comfort and fluid continuous motion remain unaccepted. Still captures do not close these items. |
| Audio | Reverie and five soft Kenney footstep blends replace earlier runtime music/steps; offline decoding passed in the archive. Live listening and final balance remain unverified. No Sky recordings are included. |
| Mobile | No physical iPhone/iPad or Android device is connected or tested. Device frame time, memory, thermal behavior, native interruption delivery and touch usability remain pending. There is no ready IPA or store release. |
| Repository | Historical builds, import caches, large review outputs and private profiles are excluded. Upload/remote commit verification must be recorded after it actually happens. |

Do not add decorative effects to conceal visible inconsistencies. Keep fixes scoped to observed defects and the agreed clearing/home MVP. A passing parser, screenshot, source benchmark or local Git commit establishes only that specific result.
