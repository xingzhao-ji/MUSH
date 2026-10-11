# Development status

This is experimental 0.6.0 source derived from combined243 and curated into a portable repository. It retains the paving preview, safe-placement/controller work, visual paw correction, shared environment and refreshed audio. Ordinary development uses normal input and a separate `MUSH-dev` save profile. A separate [mac061 candidate](MAC-CANDIDATE.md) is now exported and tested. The archive's 0.5.7 app remains the accepted reference build; 0.5.5 remains rollback.

**Fresh correctness checks pass; the sustained Mac frame-time gate does not. The private GitHub baseline was uploaded and independently cloned successfully.** See [verification evidence](VERIFICATION.md) and the [compact summary](verification-summary.json) for exact scope and receipts.

| Area | Current evidence and next gate |
| --- | --- |
| Gameplay | Fresh portable-source acceptance passes all 295 assertions across 15 scenarios. Ordinary new-game, glow, pause, weather, Save & quit and Continue were observed in the exported UI. Sustained movement/camera feel remains unaccepted. |
| Environment/materials | 133 environment checks pass. Original and allocation-cleaned material forwarding each pass 32 checks and 14,867 native comparisons. No visual ownership or simulation framework was replaced. |
| Paving/collisions | Combined startup is retained. Historical binding/rollback traces include moving roof contacts; near-cut coverage and the aggregate full-route contact gate remain open. Material tests and screenshots do not replace traversal coverage. |
| Performance | The latest textured-source 120-second night/rain route completes two loops without stalls: p95 18.476 ms and p99 19.446 ms, still above the unchanged 16.7 ms p95 limit. Earlier failures remain recorded. Preserve all failures; no measured speedup or GPU/mobile result is claimed. |
| Visuals | Four native 960 × 960 stills decode successfully. Entrance tops now use the isolated/tested Rock01 stone surface. Thick dark paving fronts, wide moss gaps, night readability, shadows/contact, scenery/reference fidelity and water joins still need review. The character is provisional. |
| Motion/audio | A short offline in-engine clip is retained; continuous real-time motion quality, manual camera comfort, live listening and final audio balance remain pending. Reverie/Kenney attribution remains; no Sky recordings are included. |
| Storage/repository | 25 archive-backed extracted apps removed; 842 reports compressed with byte-exact readback. Source/assets/notices/tests are curated separately; generated outputs/private data are excluded. Repository pack measured 35.83 MiB. Private GitHub upload and exact remote-clone verification completed at `08c4187` (242 files). |
| Mobile | No physical devices tested. Device frame time, memory, thermal behavior, interruption handling and touch usability remain pending. No ready IPA or store release. |

Do not weaken frame budgets or claim historical benchmarks qualify changed source. Diagnose measured costs, preserve scenery and rerun affected checks. Keep new features within the clearing/home MVP; resolve visible inconsistencies before adding decorative effects.
