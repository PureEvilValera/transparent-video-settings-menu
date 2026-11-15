# Transparent Video Settings Menu

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
bundle/horizon-native.json                     the .hnmod manifest (exact pins)
bundle/mixins/transparent_video_settings_menu/horizon-mixin.toml   injections
bundle/mixins/transparent_video_settings_menu/backdrop.rs
bundle/mixins/transparent_video_settings_menu/blur.rs
compatibility.json                             pinned Horizon / horizon-mixins revisions
repack.sh                                      re-pin, validate with `plan`, repack
```

## Re-pin

After a Horizon update:

```sh
./repack.sh
```

It reads the revision the instance's build used from
`~/.local/share/horizon-launcher/versions/<version>/native-mods.json`, rewrites
both pins, runs `horizon-mixins plan` against the pristine source (a target that
moved fails here, not at build time) and repacks the bundle into
`~/.local/share/horizon/horizon-native-mods/` and `dist/`. Then build again.

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

## Release

```sh
./repack.sh
gh release create v0.1.0 dist/transparent_video_settings_menu-0.1.0.hnmod \
  --title "0.1.0" --notes "Drops the dimming and blur behind Horizon's settings screens in a world."
```

`dist/` and `*.hnmod` are gitignored: the bundle is a release asset, the sources
in `bundle/` are what the registry reviews.

License: [MIT](LICENSE).
