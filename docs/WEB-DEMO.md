# Original-game web demo

The browser build exports `main.tscn` and the existing GDScript game through official Godot 4.7.2. It is the actual 3D game, with its original movement, interactions, menus, physics and save store. It is not an HTML reconstruction or video player.

## Play and save

Use a current desktop Chromium-based browser or Firefox with WebGL 2 enabled. Click **Begin a new clearing** (or **Continue** for an existing browser save).

- W/A/S/D: walk; mouse: look
- Space: hold Float; G: toggle Glow
- E: displayed interaction; B: decorate inside the home
- Escape: pause, settings and sky/weather
- In the pause menu, choose **Save** before closing the page. Reloading the same site offers **Continue** after a valid save is found.

Saves stay in that browser's IndexedDB storage for the site's origin. They are separate from native MUSH saves. Private browsing, blocked storage, clearing site data or browser eviction can remove/prevent persistence. Prefer opening the game directly rather than in a third-party iframe.

## Reproduce the export

Download the official [Godot 4.7.2 editor and export templates](https://godotengine.org/download/archive/4.7.2-stable/). Extract `web_nothreads_release.zip` from the template archive. From the repository:

```bash
GODOT_BIN=/absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
GODOT_WEB_TEMPLATE=/absolute/path/web_nothreads_release.zip \
bash tools/export_web.sh builds/web
python3 -m http.server 8000 --directory builds/web
```

Open `http://localhost:8000/`. The helper exports the committed Git revision, not uncommitted working-tree changes. It verifies the exact engine version, uses a temporary copy and isolated export settings, and leaves native source/settings/saves unchanged. Linux, Bash, Python 3 and Git are needed for this helper.

The export uses Compatibility/WebGL 2, no threads/GDExtension, and a web-only Stream audio override so the existing procedural rain generator can run. Staging renderer overrides select Compatibility; no gameplay script is rewritten. The generated `build-provenance.json` identifies the commit, engine, file sizes and SHA256 values. A fresh build does not automatically inherit another build's browser-test result.

## Hosting

Serve the complete output directory over HTTPS, keeping generated filenames together. A single-threaded export does not need COOP/COEP headers. Serve `.wasm` as `application/wasm`. This snapshot is approximately 195 MiB uncompressed: 157 MiB PCK plus 38 MiB WASM. Normal HTTP gzip can reduce those two transfers to about 67 MiB combined. Do not rename gzip bytes to `.pck`/`.wasm` without the corresponding `Content-Encoding: gzip` response header.

The PCK exceeds GitHub's 100 MB Git-file limit. Build it in the existing Pages workflow and upload it as part of the Pages artifact, rather than committing the generated binary. Keep license notices and credits in the artifact.

## Verification and limits

The versioned demo uses `9874b92`, before the newer single-tail refinement on main. It does not replace or roll back that newer source.

On October 12, 2026, source `9874b92d65679ee6625fffa4511b7f6f64f8cfff` was exported with official `4.7.2.stable.official.ed1daf0bf` and exercised in Chromium/WebGL 2 on a cloud computer:

- The native baked clearing, title and original 3D character scene rendered.
- Begin, keyboard W/G input, Escape/pause and keyboard menu navigation were exercised.
- Save visibly reported **Clearing saved.**
- A full reload retained a valid save and displayed **Continue**.
- Continue returned to the original 3D scene, and Escape opened the pause menu again.

These are bounded browser UI/save checks, not whole-game acceptance, quantified movement/camera tests or a performance benchmark. Cloud software rendering and first-use shader compilation were very slow. Hardware-accelerated desktop responsiveness, Safari, physical mobile devices, Float/interaction/decorating routes and live audio listening remain unverified. Native Forward+/Metal benchmarks do not establish browser performance or visual parity. The separate raw-IndexedDB inspection harness encountered a datetime serialization error; save persistence evidence comes from the game's validated reload flow.

The experimental 0.6.0 art/gameplay issues documented in [STATUS.md](STATUS.md) and [VERIFICATION.md](VERIFICATION.md) remain open.
