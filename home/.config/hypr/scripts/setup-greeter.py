#!/usr/bin/env python3
"""Install the reviewed MD3 ReGreet theme; run once with sudo."""
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib

SOURCE = Path(__file__).resolve().parent.parent / 'greeter'
USER_HOME = SOURCE.parents[2]
DEFAULTS = dict(SURFACE='#141218', CARD='#211e29', BUTTON='#302a3d', HOVER='#3b334b',
                PRIMARY='#d0bcff', ON_PRIMARY='#381e72', TEXT='#e6e0e9', MUTED='#cac4d0', ERROR='#ffb4ab')
ROLES = dict(SURFACE='surface', CARD='cardSurface', BUTTON='cardInteractive', HOVER='cardHover',
             PRIMARY='primary', ON_PRIMARY='textPrimary', TEXT='textSurface', MUTED='muted', ERROR='error')

def render_css():
    try: palette = json.loads((USER_HOME / '.cache/md3/colors.json').read_text())
    except (OSError, ValueError): palette = {}
    result = (SOURCE / 'regreet.css.in').read_text()
    for token, fallback in DEFAULTS.items():
        value = palette.get(ROLES[token], fallback)
        if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value): value = fallback
        result = result.replace('@' + token + '@', value)
    return result

def config_with_command(text):
    command = 'env GTK_USE_PORTAL=0 GDK_DEBUG=no-portals XKB_DEFAULT_LAYOUT=us,ru XKB_DEFAULT_OPTIONS=grp:caps_toggle dbus-run-session /usr/bin/cage -s -d -- /etc/greetd/md3/launch-regreet'
    match = re.search(r'(?ms)^\[default_session\]\s*\n(.*?)(?=^\[|\Z)', text)
    if not match: raise ValueError('Missing [default_session] in /etc/greetd/config.toml')
    body = match[1]
    body, count = re.subn(r'(?m)^\s*command\s*=.*$', 'command = ' + json.dumps(command), body)
    if count != 1: raise ValueError('Expected one greeter command')
    result = text[:match.start(1)] + body + text[match.end(1):]
    tomllib.loads(result)
    return result

def install(source, destination, mode=0o644):
    shutil.copyfile(source, destination)
    os.chmod(destination, mode)

def main():
    if os.geteuid() != 0: raise SystemExit('Run with sudo: sudo python3 ' + str(Path(__file__).resolve()))
    config = Path('/etc/greetd/config.toml')
    updated = config_with_command(config.read_text())
    tomllib.loads((SOURCE / 'regreet.toml').read_text())
    css = render_css()
    if not shutil.which('wlr-randr'):
        subprocess.run(['pacman', '-S', '--needed', 'wlr-randr'], check=True)
    for binary in ['cage', 'regreet', 'dbus-run-session', 'ffmpeg']:
        if not shutil.which(binary): raise SystemExit('Missing program: ' + binary)
    try:
        selected = json.loads((USER_HOME / '.local/state/md3/wallpaper.json').read_text())
        wallpaper = Path(selected.get('preview') if selected.get('video') else selected['path'])
    except (OSError, ValueError, KeyError, TypeError): wallpaper = Path('/usr/share/hypr/wall0.png')
    if not wallpaper.is_file(): wallpaper = Path('/usr/share/hypr/wall0.png')
    with tempfile.TemporaryDirectory(prefix='md3-greeter-') as directory:
        background = Path(directory) / 'background.jpg'
        subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(wallpaper), '-frames:v', '1',
                        '-vf', 'scale=2560:1440:force_original_aspect_ratio=decrease,eq=brightness=-0.12', str(background)], check=True)
        backup = Path('/etc/greetd-backup-md3-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
        shutil.copytree('/etc/greetd', backup)
        target = Path('/etc/greetd/md3');target.mkdir(parents=True, exist_ok=True);target.chmod(0o755)
        install(SOURCE / 'launch-regreet', target / 'launch-regreet', 0o755)
        install(SOURCE / 'regreet.toml', Path('/etc/greetd/regreet.toml'))
        install(background, target / 'background.jpg')
        Path('/etc/greetd/regreet.css').write_text(css)
        Path('/etc/greetd/regreet.css').chmod(0o644)
        temporary = config.with_suffix('.toml.tmp');temporary.write_text(updated);temporary.chmod(0o644);temporary.replace(config)
    print('Configured: centered form on DP-1, MD3 theme and session wallpaper.')
    print('Backup:', backup)
    print('Applies at the next login screen. The current session remains running.')

if __name__ == '__main__':
    main()
