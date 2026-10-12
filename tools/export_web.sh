#!/usr/bin/env bash
# Export the committed, original MUSH game with web-only platform settings.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:-$ROOT/builds/web}")"
: "${GODOT_BIN:?Set GODOT_BIN to the official Godot 4.7.2 executable}"
: "${GODOT_WEB_TEMPLATE:?Set GODOT_WEB_TEMPLATE to official 4.7.2 web_nothreads_release.zip}"
GODOT_BIN="$(realpath "$GODOT_BIN")"
GODOT_WEB_TEMPLATE="$(realpath "$GODOT_WEB_TEMPLATE")"
test -s "$GODOT_WEB_TEMPLATE"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$WORK/source" "$DEST"
VERSION="$("$GODOT_BIN" --version)"
test "$VERSION" = '4.7.2.stable.official.ed1daf0bf'
SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" archive "$SOURCE_COMMIT" | tar -x -C "$WORK/source"
python3 - "$WORK/source/project.godot" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);text=p.read_text()
for section,setting,value in [('rendering','renderer/rendering_method.web','"gl_compatibility"'),('rendering','renderer/rendering_method.mobile','"gl_compatibility"'),('audio','general/default_playback_type.web','0')]:
    marker='['+section+']'
    if marker not in text:text+='\n'+marker+'\n'
    start=text.index(marker)+len(marker)
    end=text.find('\n[',start)
    if end<0:end=len(text)
    body=text[start:end]
    body=re.sub(r'^'+re.escape(setting)+r'=.*\n?', '', body, flags=re.M)
    text=text[:start]+body.rstrip()+'\n'+setting+'='+value+'\n'+text[end:]
p.write_text(text)
PY
cat > "$WORK/source/export_presets.cfg" <<EOF
[preset.0]
name="Web"
platform="Web"
runnable=true
advanced_options=true
custom_features=""
export_filter="all_resources"
include_filter="assets/licenses/*,assets/credits.json,assets/world/*.json,lineage/**/*.json,baked/*.res,baked/*.json"
exclude_filter="review/*,reports/*,tools/*,builds/*,assets/generate_audio.py,tests/test_*"
script_export_mode=0
[preset.0.options]
custom_template/release="$GODOT_WEB_TEMPLATE"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
EOF
"$GODOT_BIN" --headless --path "$WORK/source" --editor --import
"$GODOT_BIN" --headless --path "$WORK/source" --export-release Web "$DEST/index.html"
for name in index.html index.js index.wasm index.pck; do test -s "$DEST/$name"; done
cp "$WORK/source/LICENSE.md" "$DEST/LICENSE.md"
cp "$WORK/source/assets/credits.json" "$DEST/credits.json"
mkdir -p "$DEST/licenses"
cp "$WORK/source/assets/licenses/"* "$DEST/licenses/"
python3 - "$DEST" "$SOURCE_COMMIT" "$VERSION" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1])
data={'source_repository':'https://github.com/xingzhao-ji/MUSH','source_commit':sys.argv[2],'engine':sys.argv[3],'renderer':'gl_compatibility','threads':False,'gameplay_scripts_modified':False,'audio_web_override':'Stream','browser_play_verified':False,'files':{p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in root.iterdir() if p.is_file() and p.name!='build-provenance.json'}}
(root/'build-provenance.json').write_text(json.dumps(data,indent=2)+'\n')
PY
printf 'Exported committed MUSH %s to %s\n' "$SOURCE_COMMIT" "$DEST"
