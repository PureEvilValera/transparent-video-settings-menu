# Transparent Video Settings Menu

Deprecated in Horizon from 18.11.2026

A [Horizon](https://github.com/ludovic111/horizon) native mod (a
[horizon-mixins](https://github.com/horizon-rust/horizon-mixins) source-mixin
bundle) that keeps the world visible while the settings screens are open: no
dimming, no menu blur behind them.

Tuning a shader pack means changing a value and looking at the world. Vanilla's
settings screens cover it with a tiled background, a see-through veil and a
blur, so every change means closing the screen and opening it again. This mod
draws nothing under them while a world is loaded.

Mod id `transparent_video_settings_menu` (registry ids are lowercase letters,
digits and `_`); the display name is "Transparent Video Settings Menu".

| Where | Before | After |
|---|---|---|
| Graphics, controller, shader-pack screens in a world | background + veil + blur | the world, as drawn |
| Title screen | unchanged | unchanged |
| Other menus (pause, statistics, advancements) | unchanged | unchanged |

## Install

1. Copy `transparent_video_settings_menu.hnmod` into `~/.local/share/horizon/horizon-native-mods/`.
2. Turn it on: add `mod.transparent_video_settings_menu:true` to `~/.local/share/horizon/horizon-mods.txt`.
3. Build: the launcher's **Mods** page → **Build**, or

   ```sh
   horizon-launcher native-build --trust-native-code
   ```

Native mods are not sandboxed: they are compiled into the client and run with
your rights. Read the source before building it.

Built against Horizon `9f42064c11efe7ef3e5ed2baad7ddc2a3b36eea0` (Nightly
2026-11-13) with horizon-mixins `5a64af938ec86b00d53d16a408aabc0038fb3e57`.
On another build the launcher may need `--allow-version-mismatch`, or re-pin the
bundle first (see [Re-pin](#re-pin)).

## What it patches

| Injection | Target | Behavior |
|---|---|---|
| `backdrop` (HEAD, cancellable) | `horizon_client_render::settings_shell::backdrop` | `Break(())` when `in_world`: the tiled background and the veil are never drawn; the body and its theme colours are left to the game, so a moved colour does not break this mod |
| `blur` (HEAD, cancellable) | `horizon_client::game::screen_backgrounds::Game<'_>::menu_blur` | `Break(None)` when a world is loaded and the screen is `Screen::Options`, so `menuBackgroundBlurriness` does not blur it |

`settings_shell::backdrop` is shared by `graphics_ui`, `controller_ui` and
`shader_ui`, so all three lose the dimming in a world. Outside a world the
original look is kept.

## Layout

```text
bundle/mixins/transparent_video_settings_menu/horizon-mixin.toml   injections, the mod's id and version
bundle/mixins/transparent_video_settings_menu/backdrop.rs
bundle/mixins/transparent_video_settings_menu/blur.rs
compatibility.json                             pinned Horizon / horizon-mixins revisions
repack.sh                                      re-pin, validate, package and install locally
tools/ci.py                                    the same two steps for CI (check, package)
```

## Re-pin

After a Horizon update:

```sh
./repack.sh
```

It reads the revision the instance's build used from
`~/.local/share/horizon-launcher/versions/<version>/native-mods.json`, rewrites
both pins, validates the bundle (`tools/ci.py check`), packages it
(`tools/ci.py package`) and installs the result into
`~/.local/share/horizon/horizon-native-mods/`. Then build again.

`HORIZON_REVISION=<commit> ./repack.sh` pins another Nightly than the one the
instance plays.

`E_TARGET_NOT_FOUND` means a target function was renamed: fix `target` in
`bundle/mixins/transparent_video_settings_menu/horizon-mixin.toml`. If a mod does not validate at
build time the launcher skips it with a warning in `native/build.log`, and the
game is built without the patch.

## Uninstall

```sh
rm ~/.local/share/horizon/horizon-native-mods/transparent_video_settings_menu.hnmod
sed -i '/mod.transparent_video_settings_menu/d' ~/.local/share/horizon/horizon-mods.txt
horizon-launcher native-build --trust-native-code
```

## Limitations

- In-world only; the title screen and the HUD editor keep their look.
- The veil is dropped for every screen on the settings shell, not only Graphics.
- Blur is dropped for `Screen::Options` only; the pause menu, statistics and
  advancements still blur the world when `menuBackgroundBlurriness` is over 0.
- Like any native mod, it pins one Horizon commit and must be rebuilt for a new
  one.

## Continuous integration

`tools/ci.py` is the whole pipeline; the workflows only call it.

| Workflow | Runs on | Does |
|---|---|---|
| `.github/workflows/check.yml` | every push, every pull request | `tools/ci.py check`: downloads Horizon's source archive at the pinned commit, builds horizon-mixins at the pinned commit, and has it `plan` the bundle. Then packages it and asserts the archive holds `horizon-native.json`, the bundle's sources and `mixins/<id>/LICENSE`. |
| `.github/workflows/release.yml` | tags `v*` | the same check, then `tools/ci.py package`, then `gh release create <tag> dist/<id>-<version>.hnmod` with the SHA-256 in the notes. It fails unless the tag is `v<version>` from `horizon-mixin.toml`. |

The game itself is **not** compiled in CI. That check (on the newest Nightly,
together with the popular native mods) is the registry's own `native-compat`
job, and a Horizon build needs tens of GB and minutes of CPU per comment; the
local launcher does it better.

What the workflows need: nothing but `contents: write` on the release job
(`gh` and `GITHUB_TOKEN` are on the runner already). No secrets, no launcher, no
game files.

```sh
# the same two steps locally, against the sources the launcher already has
HORIZON_SOURCE=~/.local/share/horizon-launcher/native/source/<commit> python3 tools/ci.py check
python3 tools/ci.py package
```

`tools/ci.py package` is deterministic: fixed timestamps, sorted entries, zip
header forced to Unix, so the same sources always give the same SHA-256. It
writes the manifest with `"hooks": 1`: this bundle injects by source target, not
by a named hook point, so any Horizon can carry it, and a target that moved is a
skip with a warning in `native/build.log` rather than a failed build.

Releasing is then: bump `version` in `bundle/mixins/<id>/horizon-mixin.toml`,
commit, `git tag v0.1.2 && git push --tags`. `dist/` and `*.hnmod` stay
gitignored: the bundle is a release asset, the sources in `bundle/` are what the
registry reviews.

License: [MIT](LICENSE).
