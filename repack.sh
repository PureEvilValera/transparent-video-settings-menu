#!/usr/bin/env bash
# Re-pins, validates and repacks transparent_video_settings_menu after a Horizon update.
# Nothing is built here: the launcher's Mods page Build (or
# `horizon-launcher native-build --trust-native-code`) compiles it.
#
# Overridable: HORIZON_DATA (launcher data), HORIZON_GAME (instance folder).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
data=${HORIZON_DATA:-$HOME/.local/share/horizon-launcher}
game=${HORIZON_GAME:-$HOME/.local/share/horizon}
bundle=$here/bundle
manifest=$bundle/horizon-native.json
mixin=$bundle/mixins/transparent_video_settings_menu/horizon-mixin.toml
installed=$game/horizon-native-mods/transparent_video_settings_menu.hnmod
enabled_file=$game/horizon-mods.txt
dist=$here/dist

# The Horizon revision and horizon-mixins hash the instance's build used.
installed_version=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["instances"]["horizon"]["version"])' \
  "$data/instances.json")
info=$data/versions/$installed_version/native-mods.json
revision=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["horizon"])' "$info")
mixins=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["horizon_mixins"])' "$info")
source=$data/native/source/$revision
tool=$data/native/tools/${mixins:0:12}/bin/horizon-mixins
rust=$(ls -d "$data"/rust/*/bin)
version=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$manifest")

[ -d "$source" ] || { echo "no Horizon source at $source" >&2; exit 1; }
[ -x "$tool" ] || { echo "no horizon-mixins at $tool" >&2; exit 1; }

echo "Horizon $revision, horizon-mixins $mixins"

# Re-pin both manifests, and compatibility.json.
python3 - "$manifest" "$mixin" "$here/compatibility.json" "$revision" "$mixins" <<'PY'
import json, re, sys
manifest, mixin, compat, revision, mixins = sys.argv[1:]
def rewrite(path, subs):
    with open(path) as f:
        text = f.read()
    for pattern, value in subs:
        text, n = re.subn(pattern, value, text)
        if n == 0:
            raise SystemExit(f"{path}: pattern {pattern!r} not found")
    with open(path, "w") as f:
        f.write(text)
rewrite(manifest, [(r'"horizon": "[0-9a-f]{40}"', f'"horizon": "{revision}"'),
                   (r'"mixins": "[0-9a-f]{40}"', f'"mixins": "{mixins}"')])
rewrite(mixin, [(r'horizon_revision = "[0-9a-f]{40}"', f'horizon_revision = "{revision}"')])
rewrite(compat, [(r'"horizon_revision": "[0-9a-f]{40}"', f'"horizon_revision": "{revision}"'),
                 (r'"horizon_mixins_revision": "[0-9a-f]{40}"', f'"horizon_mixins_revision": "{mixins}"')])
json.load(open(manifest))
json.load(open(compat))
PY

# Validate against the pristine source, exactly as the launcher will.
mkdir -p "$here/out"
CARGO_HOME=${CARGO_HOME:-$data/cargo} \
PATH=$rust:$PATH \
RUSTC=$rust/rustc \
"$tool" plan --workspace "$source" --mods "$bundle/mixins" --out "$here/out/plan.json" >"$here/out/plan.log" 2>&1 || {
  echo "plan failed:" >&2
  cat "$here/out/plan.log" >&2
  exit 1
}
echo "plan ok"

# Pack: horizon-native.json + mixins/transparent_video_settings_menu/ inside the zip.
pack() {
  python3 - "$bundle" "$1" <<'PY'
import os, sys, zipfile
root, out = sys.argv[1:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, _, names in os.walk(root):
        for name in sorted(names):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(full, "rb") as f:
                z.writestr(info, f.read())
PY
}

mkdir -p "$(dirname "$installed")" "$dist"
rm -f "$installed" "$dist/transparent_video_settings_menu-$version.hnmod"
pack "$installed"
pack "$dist/transparent_video_settings_menu-$version.hnmod"
echo "packed: $installed"
echo "packed: $dist/transparent_video_settings_menu-$version.hnmod"

# Turn it on for the instance (horizon-mods.txt, like any mod).
touch "$enabled_file"
grep -qx 'mod.transparent_video_settings_menu:true' "$enabled_file" || printf 'mod.transparent_video_settings_menu:true\n' >>"$enabled_file"

cat <<EOF

Next: Mods page -> Build, or

  horizon-launcher native-build --trust-native-code
EOF
