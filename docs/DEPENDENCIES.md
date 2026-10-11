# Dependencies and reuse

The game uses Godot's existing facilities and retained project code. No new add-on framework was installed. One data-only stone texture is reused through the existing material.

| Component | Pin / license | Integration and cost |
| --- | --- | --- |
| Godot | 4.7.2, `4.7.2.stable.official.ed1daf0bf`; MIT plus bundled notices | GDScript, native geometry/physics, rendering, audio, SkeletonModifier3D and VirtualJoystick. Desktop qualification uses Forward+/Metal. Install engine and matching export templates separately. |
| Reverie — Scott Buckley | CC BY 4.0; exact asset digest in assets/credits.json | Existing native MP3 player; gain/fades, silence interval and re-encoding documented in the audio notice. Human listening/balance remains pending. |
| Kenney Impact Sounds 1.0 | CC0; derived WAV digests in assets/credits.json | Five carpet/grass blends through Godot's existing audio randomizer. No per-surface classifier or extra audio framework. |
| Rock 01 — Rob Tuytel / Poly Haven | CC0 1.0; SHA256 in assets/credits.json | One pinned 1K JPEG (688,083 bytes), native mipmaps and the existing tactile shader. Replaces custom stone albedo authoring; no code, plugin, API service or new physics. |
| Python | Python 3 standard library; development tool only | Portable verification orchestration and evidence checks. No game runtime dependency. |
| Superpowers workflow | obra/superpowers commit `8ca22dba9a94f28898bbce59f2537ff4d87c747d`; MIT | Planning, systematic debugging, testing and verification practices were inspected and reused in the local archive. No game code, global hooks or duplicate plugin installation. |

Sources: [Godot](https://github.com/godotengine/godot), [Reverie](https://www.scottbuckley.com.au/library/reverie/), [Kenney](https://kenney.nl/assets/impact-sounds), [pinned Superpowers](https://github.com/obra/superpowers/tree/8ca22dba9a94f28898bbce59f2537ff4d87c747d).

Canonical Superpowers setup was rechecked on October 10, 2026: its current README directed Codex App/CLI users to the plugin marketplace; the old `.codex/INSTALL.md` path returned 404. The inspected project pin remained unchanged. This workflow reference is not an installation instruction or authorization to execute downloaded repository commands.

Current paving uses native ArrayMesh, MeshLibrary, resource loading and existing install/rollback owners. The paw modifier uses the engine's two-ray/bone facilities. These choices avoid overlapping geometry, physics and IK frameworks. Their actual verification scope is in [VERIFICATION.md](VERIFICATION.md); exact mobile performance is unmeasured.

The archive retains evaluations of GodotIK, FootIKController, weather/wind add-ons, joystick/testing packages and an audio manager. They were not adopted into this repository. Rock01 was selected over the warmer, coarser Rock08 after an isolated eight-image comparison and exact material rollback. Its grain improves the top surface but does not fix slab thickness or gaps. Imported cache is about 1.9 MiB; native image readback and frame-time evidence are documented separately. Exact mobile GPU cost remains unmeasured. Stars and upstream popularity were not treated as compatibility or performance evidence.

Keep [asset credits](../assets/credits.json), [audio attribution](../assets/licenses/AUDIO-CREDITS.txt), [Godot notices](../assets/licenses/GODOT-COPYRIGHT.txt) and [license scope](../LICENSE.md). User reference pixels are excluded. Generated bark/moss textures retain recorded provenance limitations; do not relabel them as CC0 or infer release clearance from this private repository.
