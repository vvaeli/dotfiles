#!/usr/bin/env python3
"""Copy the live md3 desktop config from $HOME into home/ of this repository.

Run it after changing something on the desktop, then commit. Personal bits stay out:
backups, caches, test harnesses, hardware specific scripts (RGB, disks) and the monitor
layout. The home directory is written as @HOME@ and the user name as @USER@; install.sh
puts the installing user's values back.
"""
import fnmatch
import getpass
import os
from pathlib import Path
import shutil
import sys

REPO = Path(__file__).resolve().parent
HOME = Path.home()
USER = getpass.getuser()

# Paths relative to $HOME. A directory is copied whole, minus EXCLUDE.
INCLUDE = [
    '.config/hypr',
    '.config/quickshell/md3',
    '.config/systemd/user/xdg-desktop-portal-gtk.service.d',
    '.config/systemd/user/xdg-desktop-portal-hyprland.service.d',
    '.config/xdg-desktop-portal/hyprland-portals.conf',
    '.config/gtk-3.0/gtk.css', '.config/gtk-3.0/thunar-md3.css', '.config/gtk-3.0/md3-colors.css', '.config/gtk-3.0/settings.ini',
    '.config/gtk-4.0/gtk.css', '.config/gtk-4.0/md3-colors.css', '.config/gtk-4.0/settings.ini',
    '.config/ghostty/config.ghostty', '.config/ghostty/md3-ansi', '.config/ghostty/themes/md3',
    '.config/btop/themes/md3.theme',
    '.config/qt6ct/qt6ct.conf', '.config/qt6ct/colors/md3.conf',
    '.config/qt5ct/qt5ct.conf', '.config/qt5ct/colors/md3.conf',
    '.config/Vencord/themes/md3.css',
    '.config/spicetify/Themes/md3',
    '.local/share/Steam/millennium/themes/md3',
    '.local/state/md3/colors.json',
]
# Matched against the path relative to $HOME and against the bare file name.
EXCLUDE = [
    '*.bak*', '*.tmp', '__pycache__', '*.pyc', '.git',
    '*-check.qml', '*-preview.qml', '.config/quickshell/md3/preview.qml',
    '.config/quickshell/md3/tools/nightlight/md3-nightlight',  # built by install.sh
    '.config/hypr/conf/monitors.lua', '.config/hypr/hyprpaper.conf',  # repo keeps generic versions
    '.config/hypr/scripts/rgb*', '.config/hypr/scripts/RGB.md',
    '.config/hypr/scripts/dev-mount', '.config/hypr/scripts/setup-dev-mount.py', '.config/hypr/scripts/setup-disks.py',
]
# Files the repo owns: written once by hand, never overwritten by a sync.
KEEP = {'.config/hypr/conf/monitors.lua', '.config/hypr/hyprpaper.conf'}


def excluded(relative):
    return any(fnmatch.fnmatch(relative, pattern) or fnmatch.fnmatch(Path(relative).name, pattern) for pattern in EXCLUDE)


def files(relative):
    source = HOME / relative
    if source.is_file():
        yield relative
    elif source.is_dir():
        for root, directories, names in os.walk(source):
            base = Path(root).relative_to(HOME)
            directories[:] = sorted(d for d in directories if not excluded(str(base / d)))
            for name in sorted(names):
                if not excluded(str(base / name)): yield str(base / name)
    else:
        print('skip (missing):', relative, file=sys.stderr)


def templated(data):
    try: text = data.decode('utf-8')
    except UnicodeDecodeError: return data
    text = text.replace(str(HOME), '@HOME@')
    # The login greeting names whoever installs it; theme author fields keep the author.
    for before, after in ((f'"Добро пожаловать, {USER}"', '"Добро пожаловать, @USER@"'),
                          (f'greeting_msg = "{USER}"', 'greeting_msg = "@USER@"')):
        text = text.replace(before, after)
    return text.encode('utf-8')


def main():
    target = REPO / 'home'
    wanted = set()
    for entry in INCLUDE:
        for relative in files(entry):
            source, destination = HOME / relative, target / relative
            wanted.add(destination)
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_symlink():
                destination.unlink(missing_ok=True)
                destination.symlink_to(os.readlink(source))
                continue
            data = templated(source.read_bytes())
            if not destination.exists() or destination.read_bytes() != data:
                destination.write_bytes(data)
                print('updated', relative)
            shutil.copymode(source, destination)
    # Drop files that disappeared from the live config, except the ones the repo owns.
    for path in sorted(target.rglob('*'), reverse=True):
        relative = str(path.relative_to(target))
        if path.is_file() and path not in wanted and relative not in KEEP:
            path.unlink()
            print('removed', relative)
        elif path.is_dir() and not any(path.iterdir()):
            path.rmdir()


if __name__ == '__main__':
    main()
