# Development status

This is experimental 0.6.0 source derived from combined243 and curated into a portable repository. It retains the paving preview, safe-placement/controller work, visual paw correction, shared environment and refreshed audio. Ordinary development uses normal input and a separate `MUSH-dev` save profile. A separate [mac061 candidate](MAC-CANDIDATE.md) is now exported and tested. The archive's 0.5.7 app remains the accepted reference build; 0.5.5 remains rollback.

**Gameplay checks and the latest 120-second Mac benchmark pass. The full paving contact-coverage gate and whole-game acceptance remain open. The private GitHub baseline was uploaded and independently cloned successfully.** See [verification evidence](VERIFICATION.md) and the [compact summary](verification-summary.json) for exact scope and receipts.

| Area | Current evidence and next gate |
| --- | --- |
| Gameplay | Fresh portable-source acceptance passes all 295 assertions across 15 scenarios. Ordinary new-game, glow, pause, weather, Save & quit and Continue were observed in the exported UI. Sustained movement/camera feel remains unaccepted. |
| Environment/materials | 133 environment checks pass. Original and allocation-cleaned material forwarding each pass 32 checks and 14,867 native comparisons. No visual ownership or simulation framework was replaced. |
| Paving/collisions | Lower center joint narrowed from about 10 cm to 4 cm. 45 native authoring checks and all 58 isolated/installed movement routes pass. The separate upper-roof/near-cut contact-coverage gate still fails; upper geometry is retained. |
| Performance | Latest integrated 120-second night/rain source route passes: p95 16.414 ms, p99 19.119 ms, two loops and no stalls at 1920 × 1080. Prior failures remain recorded. One passing callback-interval run establishes no causal speedup, GPU/presentation timing or mobile result. |
| Visuals | Eight paired entrance PNGs decode successfully and show the narrower lower joint. Thick dark upper fronts, the upper gap, night readability, shadows/contact, scenery/reference fidelity and water joins remain unfinished. The character is provisional. |
| Motion/audio | A short offline in-engine clip is retained; continuous real-time motion quality, manual camera comfort, live listening and final audio balance remain pending. Reverie/Kenney attribution remains; no Sky recordings are included. |
| Storage/repository | Earlier cleanup removed 25 archive-backed duplicate apps and compressed 842 reports with exact readback. This successor adds 650,990 bytes of baked source data/metadata and retains original192 for rollback. About 12 GiB is free; the 10 GiB reserve remains enforced. Generated outputs and private data stay outside Git. |
| Mobile | No physical devices tested. Device frame time, memory, thermal behavior, interruption handling and touch usability remain pending. No ready IPA or store release. |

Do not weaken frame budgets or claim historical benchmarks qualify changed source. Diagnose measured costs, preserve scenery and rerun affected checks. Keep new features within the clearing/home MVP; resolve visible inconsistencies before adding decorative effects.
