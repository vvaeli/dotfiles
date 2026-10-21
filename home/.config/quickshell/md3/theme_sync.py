#!/usr/bin/env python3
"""Apply the generated md3 palette to the rest of the desktop.

matugen already wrote every application's color file (see matugen.toml). This
script switches the desktop-wide dark/light preference, which every other
application follows, and reloads applications that can pick up colors live.
Each step is optional: a missing or failing application never stops the rest.
"""
import colorsys
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

HOME = Path.home()
BASE = Path(__file__).resolve().parent
PALETTE = Path(os.environ.get('XDG_CACHE_HOME', HOME / '.cache')) / 'md3/colors.json'
# GNOME accent names with their reference hues; libadwaita apps and portals use them.
ACCENTS = {'red': 355, 'orange': 25, 'yellow': 45, 'green': 140, 'teal': 180,
           'blue': 213, 'purple': 275, 'pink': 330}


def quiet(args, timeout=20):
    try:
        subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, timeout=timeout, check=True)
        return True
    except (OSError, subprocess.SubprocessError) as error:
        detail = getattr(error, 'stderr', b'') or b''
        print(f'{args[0]}: {detail.decode("utf-8", "replace").strip() or error}', file=sys.stderr)
        return False


# Ghostty's default ANSI colors are tuned for dark backgrounds: white, yellow and
# cyan text becomes unreadable on a light surface. Light mode uses darker hues.
LIGHT_ANSI = ['#2b2522', '#ba1a1a', '#2e7d32', '#8a5a00', '#1e5bb8', '#8e3fa6', '#00737a', '#6b625c',
              '#7d746e', '#d32f2f', '#3b8c3f', '#a06a00', '#2f6fd6', '#a24fbf', '#00838f', '#4a4340']


def terminal_palette(mode):
    target = HOME / '.config/ghostty/md3-ansi'
    lines = ['# Written by theme_sync.py: ANSI colors for the current light/dark mode.']
    if mode == 'light':
        lines += [f'palette = {index}={color}' for index, color in enumerate(LIGHT_ANSI)]
    target.write_text('\n'.join(lines) + '\n')


def accent_for(color):
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hue, _, saturation = colorsys.rgb_to_hls(r, g, b)
    if saturation < 0.15: return 'slate'
    hue *= 360
    return min(ACCENTS, key=lambda name: min(abs(hue - ACCENTS[name]), 360 - abs(hue - ACCENTS[name])))


def gtk_theme(mode):
    # adw-gtk3 follows the libadwaita named colors written to md3-colors.css.
    for root in (HOME / '.local/share/themes', HOME / '.themes', Path('/usr/share/themes')):
        if (root / 'adw-gtk3-dark').is_dir():
            return 'adw-gtk3-dark' if mode == 'dark' else 'adw-gtk3'
    return 'Adwaita-dark' if mode == 'dark' else 'Adwaita'


def set_ini(path, key, value):
    if not path.exists(): return
    lines = path.read_text().splitlines()
    updated = [f'{key} = {value}' if line.split('=')[0].strip() == key else line for line in lines]
    if updated != lines: path.write_text('\n'.join(updated) + '\n')


def desktop(mode, palette):
    theme = gtk_theme(mode)
    schema = 'org.gnome.desktop.interface'
    quiet(['gsettings', 'set', schema, 'color-scheme', 'prefer-dark' if mode == 'dark' else 'prefer-light'])
    quiet(['gsettings', 'set', schema, 'gtk-theme', theme])
    if palette.get('primary'):
        # Older gsettings schemas have no accent-color key; that is not an error worth reporting.
        subprocess.run(['gsettings', 'set', schema, 'accent-color', accent_for(palette['primary'])],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for version in ('gtk-3.0', 'gtk-4.0'):
        settings = HOME / '.config' / version / 'settings.ini'
        set_ini(settings, 'gtk-theme-name', theme)
        set_ini(settings, 'gtk-application-prefer-dark-theme', 'true' if mode == 'dark' else 'false')


def hyprland():
    # hyprctl eval applies the generated colors without a config reload, which would rerun the autostart.
    colors = HOME / '.config/hypr/conf/colors.lua'
    if colors.exists() and shutil.which('hyprctl') and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        quiet(['hyprctl', 'eval', f'dofile({json.dumps(str(colors))})'])


def applications(mode):
    hyprland()
    terminal_palette(mode)
    # Ghostty reloads its configuration, including the md3 theme file, on SIGUSR2.
    subprocess.run(['pkill', '-USR2', '-x', 'ghostty'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    spicetify = shutil.which('spicetify') or str(HOME / '.spicetify/spicetify')
    config = HOME / '.config/spicetify/config-xpui.ini'
    if Path(spicetify).exists() and config.exists() \
            and re.search(r'^current_theme\s*=\s*md3\s*$', config.read_text(), re.M):
        # Without restarting: playback is not interrupted, colors appear on the next Spotify start.
        quiet([spicetify, '-n', '-q', 'refresh'], timeout=60)
    if shutil.which('pywalfox'): quiet(['pywalfox', 'update'])
    if (HOME / '.config/zed/themes/md3-shell.json').exists():
        quiet([sys.executable, str(BASE / 'zed-theme.py')])
    rgb = HOME / '.config/hypr/scripts/rgb-power'
    if rgb.exists():
        quiet(['systemctl', '--user', 'start', '--no-block', 'md3-rgb-accent.service'])
    # Login screen: palette, blurred wallpaper and avatar in /etc/greetd/md3.
    quiet([sys.executable, str(BASE / 'greeter_sync.py')], timeout=60)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ('dark', 'light') else 'dark'
    try: palette = json.loads(PALETTE.read_text())
    except (OSError, ValueError): palette = {}
    desktop(mode, palette)
    applications(mode)


if __name__ == '__main__':
    main()
