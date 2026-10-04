# Omarchy Desktop Clock

English | [简体中文](README.zh-CN.md)

https://github.com/user-attachments/assets/7a5fbda6-b6e8-4cb1-bf4b-3e2f967ec501

A terminal-style desktop clock for Omarchy, with theme colors and a shared draggable position across monitors.

## Features

- Appears only on each monitor's empty workspace. Opening an application window hides the clock on that monitor.
- Colors and fonts follow the Omarchy theme. Displays local time in 24-hour format, with seconds, date and localized short weekday names.
- Drag with the left mouse button to position the clock. The saved relative position is shared across all monitors and workspaces.
- Stops without easing when the pointer stops. Releasing the mouse keeps the same visible window and saves the position once.
- Sits above the wallpaper without reserving screen space or taking keyboard focus. Side panels and Wave do not count as application windows.
- Uses an independent software renderer to keep clock rendering separate from Omarchy and Wave. Clock timers stop when the current workspaces on all monitors are occupied.

## Install

Requires Omarchy with Quickshell and Hyprland using Lua configuration. The installer also uses Bash, Python 3, jq and GNU coreutils, which are included in Omarchy.

```sh
git clone https://github.com/manateelazycat/omarchy-desktop-clock.git
cd omarchy-desktop-clock
bash install.sh
```

The installer backs up your configuration to `~/.local/state/omarchy/desktop-clock/backups/` and installs the plugin under `~/.config/omarchy/plugins/io.github.manateelazycat.desktop-clock/`.
It adds animation rules for the clock, reloads Hyprland and checks for configuration errors. Other desktop animations keep their current settings.
`XDG_CONFIG_HOME` and `XDG_STATE_HOME` are respected when set.

Update while keeping the current enable state:

```sh
git pull
bash install.sh --no-enable
```

If installed through the marketplace or `omarchy plugin add`, run this additional setup once to add the clock's Hyprland animation rules:

```sh
bash "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.manateelazycat.desktop-clock/install.sh" --no-enable
omarchy plugin enable io.github.manateelazycat.desktop-clock
```

## Uninstall

```sh
omarchy plugin remove io.github.manateelazycat.desktop-clock
```

This unloads the clock and removes its installed plugin directory after confirmation. Omarchy backs up directories installed without Git.
The guarded include in `~/.config/hypr/hyprland.lua` does nothing once the plugin is removed. To remove it too, delete the block from `-- >>> omarchy-desktop-clock >>>` through `-- <<< omarchy-desktop-clock <<<`, then run `hyprctl reload`.
Configuration backups remain in `~/.local/state/omarchy/desktop-clock/backups/` for recovery.

## Configuration

Adjust the existing plugin entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.manateelazycat.desktop-clock",
  "positionX": 0.5,
  "positionY": 0.52,
  "scale": 1,
  "opacity": 1
}
```

`positionX` and `positionY` range from 0 to 1: 0 is the left or top edge, 1 is the right or bottom edge, and 0.5 is centered.
`scale` ranges from 0.5 to 2; `opacity` ranges from 0.2 to 1. A 24-pixel margin keeps the clock inside the screen, and smaller screens scale it down automatically.

Dragging pauses second updates until release. Position changes are saved once and restored after login.
Pinned windows and windows in an open special workspace also hide the clock on their monitor.

Set or reset the shared position:

```sh
omarchy-shell desktop-clock setPosition 0.5 0.52
omarchy-shell desktop-clock resetPosition
```

## Enable or disable

```sh
omarchy plugin disable io.github.manateelazycat.desktop-clock
omarchy plugin enable io.github.manateelazycat.desktop-clock
omarchy-shell desktop-clock status
```

Disabling the plugin stops its renderer and removes its inline configuration entry; installation backups retain the previous settings.
`status` reports the version, renderer PID, saved position and visibility on each monitor.
If an update still reports an old version, run `omarchy restart shell` to clear the host's QML cache.

## Development

```sh
omarchy plugin validate .
node --test tests/position.test.cjs
bash tests/run-runtime.sh
python tests/bridge.py
python tests/stop.py --output profiles/current-drag-stop.json --expect-stable
```

Runtime checks use separate Quickshell processes and synthetic pointer events without moving the system pointer or writing user settings.
Wave coexistence measurements and profiling results are documented in the [performance report](PERFORMANCE.md).

## License

[GPL-3.0-only](LICENSE). Copyright (C) 2026 ManateeLazyCat.
