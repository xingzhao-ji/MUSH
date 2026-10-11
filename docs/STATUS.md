# Development status

This is experimental 0.6.0 source derived from combined243 and curated into a portable repository. It retains the paving preview, safe-placement/controller work, visual paw correction, shared environment and refreshed audio. Ordinary development uses normal input and a separate `MUSH-dev` save profile. A separate [mac062 candidate](MAC-CANDIDATE.md) is now exported and tested. The archive's 0.5.7 app remains the accepted reference build; 0.5.5 remains rollback.

**Gameplay and the latest source frame-time check pass; the older exported Mac candidate still fails its recorded p95 limit. The full paving contact-coverage gate and whole-game acceptance remain open. The private GitHub baseline was uploaded and independently cloned successfully.** See [verification evidence](VERIFICATION.md) and the [compact summary](verification-summary.json) for exact scope and receipts.

| Area | Current evidence and next gate |
| --- | --- |
| Gameplay | Fresh source acceptance passes all 295 assertions across 15 scenarios. mac062 passes 12 exported startup/effects checks. Ordinary UI save/Continue was observed only on older mac061; sustained movement/camera feel remains unaccepted. |
| Environment/materials | 137 environment checks pass. Original and allocation-cleaned material forwarding each pass 32 checks and 14,867 native comparisons. No visual ownership or simulation framework was replaced. |
| Paving/collisions | Lower center joint narrowed from about 10 cm to 4 cm. 45 native authoring checks and all 58 isolated/installed movement routes pass. A newly found center-gap snag is fixed with native paired support proposals: four additional movement routes and ten support cases pass. The separate upper-roof/near-cut contact-coverage gate still fails; upper geometry is retained. |
| Performance | Latest source 120-second night/rain route passes: p95 16.389 ms / p99 18.439 ms, two loops, no stalls, 1920 × 1080. Older mac062 app remains at its failed p95 19.521 ms / p99 28.327 ms. No causal speedup or GPU/presentation/mobile result is established. |
| Visuals | Eight paired entrance PNGs decode successfully and show the narrower lower joint. Thick dark upper fronts, the upper gap, night readability (small sky-fill lift implemented), shadows/contact, scenery/reference fidelity and water joins remain unfinished. The character is provisional. |
| Motion/audio | A fully decoded 9.17-second offline walking clip covers the new regression; continuous real-time motion quality, manual camera comfort, live listening and final audio balance remain pending. Reverie/Kenney attribution remains; no Sky recordings are included. |
| Storage/repository | Earlier cleanup removed 25 archive-backed duplicate apps and compressed 842 reports with exact readback. This successor adds 650,990 bytes of baked source data/metadata and retains original192 for rollback. Another 414,265,344 allocated bytes of inactive generated caches were removed for export room. About 11.5 GiB remains free; the 10 GiB reserve remains enforced. Generated outputs and private data stay outside Git. |
| Mobile | No physical devices tested. Device frame time, memory, thermal behavior, interruption handling and touch usability remain pending. No ready IPA or store release. |

Do not weaken frame budgets or claim historical benchmarks qualify changed source. Diagnose measured costs, preserve scenery and rerun affected checks. Keep new features within the clearing/home MVP; resolve visible inconsistencies before adding decorative effects.
