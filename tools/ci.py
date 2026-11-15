#!/usr/bin/env python3
"""Validate and package this native mod in CI, the way horizon-rust's own tooling does.

    python3 tools/ci.py check               # horizon-mixins plan on the pinned Horizon
    python3 tools/ci.py package             # dist/<id>-<version>.hnmod, byte-for-byte reproducible
    python3 tools/ci.py package --source PATH   # the same, against on-disk Horizon sources

`check` downloads Horizon's source at the commit in compatibility.json (GitHub's archive,
never a checkout), builds horizon-mixins at the pinned commit, and asks horizon-mixins to plan
the bundle: a target function that moved fails here, before the registry or a player's
launcher meets it. The game itself is not compiled: the registry's own native-compat check
does that on the newest Nightly.

`package` writes the bundle the launcher installs: horizon-native.json, the bundle's Rust and
TOML, and the mod's LICENSE as mixins/<id>/LICENSE. Timestamps, order and the zip's header are
fixed, so the same sources always give the same bytes and SHA-256.
"""
import argparse
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tomllib
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = "horizon-rust/horizon"
MIXINS_REPO = "https://github.com/horizon-rust/horizon-mixins"
WORK = ROOT / ".ci"
RUST = os.environ.get("RUST_VERSION", "1.99.1")
# The hook-points version this bundle needs: it injects by source target, not by a named hook
# point, so any Horizon with the hook points at all can carry it. A moved target is skipped
# with a warning in native/build.log instead of failing the player's build.
HOOKS = 1


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def compat():
    return json.loads((ROOT / "compatibility.json").read_text())


def bundle():
    """The one mixin bundle under bundle/mixins/, with its manifest."""
    folders = [p for p in (ROOT / "bundle" / "mixins").iterdir() if (p / "horizon-mixin.toml").is_file()]
    if len(folders) != 1:
        sys.exit(f"expected one bundle in bundle/mixins/, found {[p.name for p in folders]}")
    folder = folders[0]
    manifest = tomllib.loads((folder / "horizon-mixin.toml").read_text())
    return folder, manifest


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "transparent-video-settings-menu-ci"})
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read()


def source(revision):
    """Horizon's source at `revision`, unpacked once; $HORIZON_SOURCE serves a local copy."""
    local = os.environ.get("HORIZON_SOURCE")
    if local:
        return Path(local)
    out = WORK / "horizon" / revision
    if (out / ".horizon-revision").is_file():
        return out
    log(f"Downloading Horizon {revision[:7]}")
    data = get(f"https://codeload.github.com/{REPO}/tar.gz/{revision}")
    partial = WORK / "horizon" / f".{revision}.partial"
    shutil.rmtree(partial, ignore_errors=True)
    partial.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        archive.extractall(partial, filter="data")
    top = next(partial.iterdir())
    # horizon-mixins refuses symbolic links; the source has a few in docs, none needed here.
    for path in top.rglob("*"):
        if path.is_symlink():
            path.unlink()
    (top / ".horizon-revision").write_text(revision)
    shutil.rmtree(out, ignore_errors=True)
    top.rename(out)
    shutil.rmtree(partial)
    return out


def tool(revision):
    """horizon-mixins at the pinned commit, built once."""
    root = WORK / "horizon-mixins" / revision
    binary = root / "bin" / "horizon-mixins"
    if not binary.is_file():
        log(f"Building horizon-mixins {revision[:7]}")
        subprocess.run(["cargo", "install", "--locked", "--quiet", "--git", MIXINS_REPO, "--rev", revision,
                        "--root", str(root), "horizon-mixins-cli"], check=True)
    return binary


def check():
    pinned = compat()
    revision = pinned["horizon_revision"]
    mixins = pinned["horizon_mixins_revision"]
    folder, manifest = bundle()
    id, version = manifest["mod"]["id"], manifest["mod"]["version"]
    declared = manifest.get("compatibility", {}).get("horizon_revision")
    if declared != revision:
        sys.exit(f"bundle/mixins/{folder.name}/horizon-mixin.toml pins {declared}, compatibility.json {revision}")

    tree = source(revision)
    # horizon-mixins resolves the workspace with cargo: its dependencies must be in the cache.
    if not os.environ.get("HORIZON_SOURCE"):
        log("Fetching Horizon's dependencies")
        subprocess.run(["cargo", "fetch", "--locked", "--manifest-path", str(tree / "Cargo.toml")], check=True)
    # As the launcher does when it builds a mod on another Horizon: pin the staged copy.
    mods = WORK / "mods"
    shutil.rmtree(mods, ignore_errors=True)
    mods.mkdir(parents=True)
    shutil.copytree(folder, mods / id)
    staged = mods / id / "horizon-mixin.toml"
    staged.write_text(re.sub(r'horizon_revision\s*=\s*"[0-9a-f]{40}"', f'horizon_revision = "{revision}"',
                             staged.read_text()))
    out = WORK / "plan.json"
    run = subprocess.run([str(tool(mixins)), "plan", "--workspace", str(tree), "--mods", str(mods),
                          "--out", str(out)], capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit(f"horizon-mixins plan failed:\n{run.stdout}{run.stderr}")
    plan = json.loads(out.read_text())
    injections = plan.get("injections") or []
    print(json.dumps({"id": id, "version": version, "horizon": revision, "mixins": mixins,
                      "injections": [f'{i["injection_id"]} {i["kind"]} {i["target"]}' for i in injections]},
                     indent=2))


def package():
    folder, manifest = bundle()
    id, version = manifest["mod"]["id"], manifest["mod"]["version"]
    pinned = compat()
    declared = manifest.get("compatibility", {}).get("horizon_revision")
    if declared != pinned["horizon_revision"]:
        sys.exit(f"bundle/mixins/{folder.name}/horizon-mixin.toml pins {declared}, compatibility.json "
                 f"{pinned['horizon_revision']}")
    native = {"schema": 1, "id": id, "version": version, "game": pinned["game_version"],
              "horizon": pinned["horizon_revision"], "mixins": pinned["horizon_mixins_revision"],
              "hooks": HOOKS}
    files = {"horizon-native.json": (json.dumps(native, indent=2, sort_keys=True) + "\n").encode()}
    for path in sorted(folder.rglob("*")):
        if path.is_file() and path.suffix in (".rs", ".toml"):
            files[f"mixins/{id}/{path.relative_to(folder).as_posix()}"] = path.read_bytes()
    licence = ROOT / "LICENSE"
    if licence.is_file():
        # The licence travels in the package, where Horizon's bundle reader accepts LICENSE* files.
        files[f"mixins/{id}/LICENSE"] = licence.read_bytes()
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{id}-{version}.hnmod"
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            # zipfile writes the platform it runs on into the header: fix it to Unix, as Horizon does.
            info.create_system = 3
            archive.writestr(info, content)
    print(json.dumps({"file": str(out.relative_to(ROOT)), "size": out.stat().st_size,
                      "sha256": hashlib.sha256(out.read_bytes()).hexdigest()}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["check", "package"])
    args = parser.parse_args()
    check() if args.action == "check" else package()


if __name__ == "__main__":
    main()
