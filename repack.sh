#!/usr/bin/env bash
# Re-pins, validates, packages and installs the mod locally after a Horizon update.
#
# Overridable: HORIZON_DATA (launcher data), HORIZON_GAME (instance folder),
# HORIZON_REVISION (pin another Nightly than the one the instance plays).
#
# CI does the same without a launcher: .github/workflows/check.yml runs
# `tools/ci.py check` and `tools/ci.py package` on GitHub's archive of the pinned commit.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
data=${HORIZON_DATA:-$HOME/.local/share/horizon-launcher}
game=${HORIZON_GAME:-$HOME/.local/share/horizon}
bundle=$here/bundle
manifest=$bundle/horizon-native.json
mixin=$(ls "$here"/bundle/mixins/*/horizon-mixin.toml)
id=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["id"])' "$manifest")
enabled_file=$game/horizon-mods.txt

# The Horizon revision and horizon-mixins hash the instance's build used.
installed_version=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["instances"]["horizon"]["version"])' \
  "$data/instances.json")
info=$data/versions/$installed_version/native-mods.json
revision=${HORIZON_REVISION:-$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["horizon"])' "$info")}
mixins=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["horizon_mixins"])' "$info")
source=$data/native/source/$revision

[ -d "$source" ] || { echo "no Horizon source at $source" >&2; exit 1; }

echo "Horizon $revision, horizon-mixins $mixins"

# Re-pin the bundle and compatibility.json.
python3 - "$mixin" "$here/compatibility.json" "$revision" "$mixins" <<'PY'
import json, re, sys
mixin, compat, revision, mixins = sys.argv[1:]
def rewrite(path, subs):
    with open(path) as f:
        text = f.read()
    for pattern, value in subs:
        text, n = re.subn(pattern, value, text)
        if n == 0:
            raise SystemExit(f"{path}: pattern {pattern!r} not found")
    with open(path, "w") as f:
        f.write(text)
rewrite(mixin, [(r'horizon_revision = "[0-9a-f]{40}"', f'horizon_revision = "{revision}"')])
rewrite(compat, [(r'"horizon_revision": "[0-9a-f]{40}"', f'"horizon_revision": "{revision}"'),
                 (r'"horizon_mixins_revision": "[0-9a-f]{40}"', f'"horizon_mixins_revision": "{mixins}"')])
json.load(open(compat))
PY

# Validate against the pristine source and package, as CI does.
HORIZON_SOURCE=$source CARGO_HOME=${CARGO_HOME:-$data/cargo} \
PATH=$(ls -d "$data"/rust/*/bin):$PATH \
RUSTC=$(ls -d "$data"/rust/*/bin)/rustc \
python3 "$here/tools/ci.py" check && \
HORIZON_SOURCE=$source python3 "$here/tools/ci.py" package

# Install: the same bundle the release carries.
packed=$(ls "$here"/dist/*.hnmod | tail -1)
mkdir -p "$game/horizon-native-mods"
cp -f "$packed" "$game/horizon-native-mods/$id.hnmod"
echo "installed: $game/horizon-native-mods/$id.hnmod"

# Turn it on for the instance (horizon-mods.txt, like any mod).
touch "$enabled_file"
grep -qx "mod.$id:true" "$enabled_file" || printf 'mod.%s:true\n' "$id" >>"$enabled_file"

cat <<'EOF'

Next: Mods page -> Build, or

  CARGO_BUILD_JOBS=2 horizon-launcher native-build --trust-native-code

(Fewer jobs than cores: rustc on the biggest crates needs more RAM than a small machine has.)
EOF
