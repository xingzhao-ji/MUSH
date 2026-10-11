# Development status

This is experimental 0.6.0 source, with the retained paving, movement, shared
environment and refreshed audio systems. Development saves use `MUSH-dev`.
The separate [mac063 candidate](MAC-CANDIDATE.md) is frozen before the recent
flower, terrain and forest changes; it still fails its recorded p95 limit.
The archive's 0.5.7 app remains the accepted reference and 0.5.5 remains rollback.
The user authorized as-is source uploads; the private GitHub baseline is verified.

**The current forest/contact source passes its fresh native, gameplay and
120-second frame-time checks. Whole-game art/play acceptance and the separate
paving contact-coverage gate remain open.** Exact scopes and receipts are in
[verification evidence](VERIFICATION.md) and the [compact summary](verification-summary.json).

| Area | Current evidence and next gate |
| --- | --- |
| Gameplay | Fresh 295/295 assertions across 15 scenarios pass, including indoor and fast-turn camera tests. Five trunk routes pass 25 contact checks across 855 movement ticks at both 30 and 60 rendered FPS with fixed-step physics. Ordinary save/Continue was observed only on older mac061; mac063 window access failed with cgWindowNotFound. Manual movement/camera feel remains pending. |
| Environment | 137 checks pass. The existing 30-tree layer now has 13 low, nine medium and eight tall trees with the same 450 instances/208,920 triangles, 55 spatial batches instead of 56, and shared foliage materials. Four reachable stems add 20 static cylinder shapes. A 5 cm camera inset resolves the sampled shape-cast collisions. The integrated suite passes 28 checks, 36 camera poses and ten decoded paired images. |
| Terrain and vegetation | Two cached outer soil meshes cover the old terrain edge; the stream extends in positive Z. The distant negative-Z channel beyond the original water end remains unverified. Existing cached flower/terrain resources and original rollback pointers are retained. No new texture, shader or simulation framework was added for this forest change. |
| Paving | Current roughly 4 cm joints pass 49 authoring checks, all 58 movement routes and four separate gap routes with ten native support cases. The separate upper-soil/near-cut contact-coverage gate still fails. Thick front silhouettes and night readability remain unfinished. |
| Performance | Current 120-second night/rain source route: p95 16.163 ms / p99 18.067 ms, 10,121 frames, two loops, zero stalls, 1920 × 1080/default VSync. Read-only historical cache hashing briefly overlapped this run. The frozen mac063 app still fails p95 at 18.049 ms. No causal speedup, GPU/presentation, thermal or mobile result is established. |
| Visuals | Three native cylinder shapes close the confirmed legacy trunk gap; the previously blocked turn now shows the character in the sampled frame. Native bone-center/lens checks pass at 30/60 FPS, without claiming whole-image or all-path visibility. The closest distant home still hangs about 1.92 m above sampled soil. Regular foliage bands, obscured distant windows, full reference fidelity, shadows/contact and the provisional character remain unfinished. |
| Motion/audio | A fully decoded 21.43-second, 643-frame ordinary-camera offline recording covers five trunk routes with animation and gusts. Seven sequential samples are retained; stills and bone-center queries do not prove continuous motion quality. Manual motion, live listening and final audio balance remain pending. Reverie/Kenney attribution remains; no Sky recordings are included. |
| Storage | A tracked reports/.gdignore prevents test-image imports. After 227 original PNGs fully decoded, 454 regenerable cache files totaling 244,547,584 allocated bytes (233.22 MiB) were removed. Game assets/shaders, original reports, references, saves and rollback assets remain. The new recording's working AVI was removed only after MP4 verification. About 12 GiB remains free and the 10 GiB reserve is enforced. Earlier verified archive/report cleanup remains documented. |
| Mobile/export | No new app was exported at this checkpoint. No physical devices tested; device frame time, memory, thermals, interruptions and touch use remain pending. No ready IPA or store release. |

Do not weaken budgets or use historical benchmarks to qualify changed source.
Keep work within the clearing/home MVP. Rollback before the outer-trunk correction: Git `9936133`; before forest layering: `843886c`.
