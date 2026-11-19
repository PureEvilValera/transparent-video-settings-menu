# Horizon for shader debugging

A launcher script for [Horizon](https://github.com/horizon-rust/horizon): it starts the game so
that the settings and shader-pack screens draw **no dimming** behind them. Tuning a shader pack
means changing a value and looking at the world; with this the world stays visible, instead of
having to close the screen between changes.

It is a script, not a mod: nothing is compiled into the game and nothing is installed into it
beyond one small resource pack of transparent menu textures.

## Install

```sh
mkdir -p ~/.local/bin
curl -LO https://github.com/PureEvilValera/transparent-video-settings-menu/releases/latest/download/horizon-for-shader-debug
mv horizon-for-shader-debug ~/.local/bin/
chmod +x ~/.local/bin/horizon-for-shader-debug
```

`~/.local/bin` is on `PATH` in most setups (fish: `set -gx PATH $HOME/.local/bin $PATH` if not).

## Use

```sh
horizon-for-shader-debug                 # the newest installed version
horizon-for-shader-debug 9f42064         # any installed version, by a part of its name
horizon-for-shader-debug 9f42064 --world Test
horizon-for-shader-debug --dry-run       # print what would run, change nothing
```

Version names come from the launcher; the script reads `horizon-launcher versions --installed`
(newest first), so no argument means the newest. A part of a name is enough, and a plain build
wins over a `native-…` build of the same commit.

## What it changes

| Where | Change |
|---|---|
| The instance's `resourcepacks/` | adds `see_through_settings.zip` once and keeps it on: transparent `gui/inworld_menu_background`, `gui/menu_background`, `gui/inworld_menu_list_background`, `gui/menu_list_background`, `gui/options_background` |
| The game process | `HORIZON_MENU_STYLE=vanilla`: the engine's own alternative look, whose settings pages draw on vanilla's surfaces and skip the veil |
| Everything else | nothing: versions, worlds, settings and the launcher are untouched |

Undo the pack any time:

```sh
horizon-launcher packs off see_through_settings.zip
horizon-launcher packs remove see_through_settings.zip   # to the Trash
```

## Versions

The `HORIZON_MENU_STYLE` switch exists from the **18 November** build (`0b14f8a`) on. On older
builds the script still installs the pack, and only the tiled background goes; the veil
(30 % over the world) stays. The script says so before starting.

| Build | Shader pack options | No dimming |
|---|---|---|
| 13 November (`9f42064`) and older | yes | no |
| 18 November (`0b14f8a`) and newer | yes, once the packs themselves are updated | yes |

## Requirements

- Linux, `sh`, `base64`, `python3` (the launcher needs Python anyway).
- The Horizon launcher with at least one installed version. `HORIZON_LAUNCHER` points elsewhere
  than `~/Minecraft/horizon-launcher` if needed.

## Release

Tag `v<version>`; `.github/workflows/release.yml` checks the script (syntax, and that the
embedded pack decodes to the expected five textures plus `pack.mcmeta`), then publishes the
script as the release's asset with its SHA-256.

License: [MIT](LICENSE).
