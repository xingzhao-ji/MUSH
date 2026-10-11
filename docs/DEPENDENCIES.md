# Dependencies and reuse

The game uses Godot's existing facilities and retained project code. No new add-on framework was installed for this repository cleanup.

| Component | Pin / license | Integration and cost |
| --- | --- | --- |
| Godot | 4.7.2, `4.7.2.stable.official.ed1daf0bf`; MIT plus bundled notices | GDScript, native geometry/physics, rendering, audio, SkeletonModifier3D and VirtualJoystick. Desktop qualification uses Forward+/Metal. Install engine and matching export templates separately. |
| Reverie — Scott Buckley | CC BY 4.0; exact asset digest in assets/credits.json | Existing native MP3 player; gain/fades, silence interval and re-encoding documented in the audio notice. Human listening/balance remains pending. |
| Kenney Impact Sounds 1.0 | CC0; derived WAV digests in assets/credits.json | Five carpet/grass blends through Godot's existing audio randomizer. No per-surface classifier or extra audio framework. |
| Python | Python 3 standard library; development tool only | Portable verification orchestration and evidence checks. No game runtime dependency. |
| Superpowers workflow | obra/superpowers commit `8ca22dba9a94f28898bbce59f2537ff4d87c747d`; MIT | Planning, systematic debugging, testing and verification practices were inspected and reused in the local archive. No game code, global hooks or duplicate plugin installation. |

Sources: [Godot](https://github.com/godotengine/godot), [Reverie](https://www.scottbuckley.com.au/library/reverie/), [Kenney](https://kenney.nl/assets/impact-sounds), [pinned Superpowers](https://github.com/obra/superpowers/tree/8ca22dba9a94f28898bbce59f2537ff4d87c747d).

Canonical Superpowers setup was rechecked on October 10, 2026: its current README directed Codex App/CLI users to the plugin marketplace; the old `.codex/INSTALL.md` path returned 404. The inspected project pin remained unchanged. This workflow reference is not an installation instruction or authorization to execute downloaded repository commands.

Current paving uses native ArrayMesh, MeshLibrary, resource loading and existing install/rollback owners. The paw modifier uses the engine's two-ray/bone facilities. These choices avoid overlapping geometry, physics and IK frameworks. Their actual verification scope is in [VERIFICATION.md](VERIFICATION.md); exact mobile performance is unmeasured.

The archive retains evaluations of GodotIK, FootIKController, weather/wind add-ons, joystick/testing packages and an audio manager. They were not adopted into this repository. Poly Haven stone textures were researched for an isolated trial but are not shipped here. Stars and upstream popularity were not treated as compatibility or performance evidence.

Keep [asset credits](../assets/credits.json), [audio attribution](../assets/licenses/AUDIO-CREDITS.txt), [Godot notices](../assets/licenses/GODOT-COPYRIGHT.txt) and [license scope](../LICENSE.md). User reference pixels are excluded. Generated bark/moss textures retain recorded provenance limitations; do not relabel them as CC0 or infer release clearance from this private repository.
