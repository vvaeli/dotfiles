# Screenshot pipeline

> Hotkeys now use the ShareX-style capture built into the md3 shell
> (`~/.config/quickshell/md3/screenshot.py`, see its README). This script
> stays as a fallback.

Dependencies:

```bash
sudo pacman -S grim slurp satty jq wl-clipboard libnotify
```

```bash
~/.config/hypr/scripts/screenshot area
~/.config/hypr/scripts/screenshot window
~/.config/hypr/scripts/screenshot active
~/.config/hypr/scripts/screenshot screen --no-edit
~/.config/hypr/scripts/screenshot area copy-only
```

`area` allows dragging any rectangle or clicking a predefined visible window.
`window` uses `slurp -r` and accepts only predefined window rectangles.
Only mapped, nonhidden windows on currently displayed workspaces (including
special workspaces and pinned windows) are offered; inactive workspace windows
are excluded. Negative coordinates on monitors left of the main display work.

The selected geometry is passed to `grim -g`; `screen` uses the focused output
with `grim -o`. Captures are taken after the slurp selection is finished.
The prior Quickshell frozen selection is no longer used by these commands.

Satty receives PNG on stdin with `--filename - --fullscreen`. The original
is saved before editing. `satty-sharex.toml` enables auto-copy/save-after-copy,
so annotations are saved during editing and survive normal window close.
Enter and Esc explicitly save to file, copy, and exit. Copy/save toolbar actions
also persist the image; they do not force the editor to close. The final result
is copied again and a preview notification is sent after the editor exits.
Clipboard updates during editing are intentional to preserve unsaved changes.

Screenshots use `~/Pictures/Screenshots/YYYY-MM-DD_HH-MM-SS.png`. A numeric suffix
is added for collisions; existing screenshots are never overwritten. Selection
cancellation creates no image. Temporary files are private and cleaned on exit.
A nonblocking flock prevents multiple simultaneous selectors/editors.

Active Lua bindings are in `../conf/keybindings.lua`. The traditional config
block is in `../screenshot-bindings.conf`. Super+Shift+Print is an additional
strict window picker. `selection` layer animations are disabled to prevent
selection borders from leaking into screenshots.

References:
https://github.com/emersion/slurp/blob/master/slurp.1.scd
https://github.com/Satty-org/Satty
