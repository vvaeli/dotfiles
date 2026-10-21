#!/usr/bin/env python3
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

HOME = Path.home()
ROOT = HOME / 'Pictures/Wallpapers'
CACHE = Path(os.environ.get('XDG_CACHE_HOME', HOME / '.cache')) / 'md3/wallpapers'
STATE = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'md3'
BASE = Path(__file__).resolve().parent
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.avif'}
VIDEOS = {'.mp4', '.webm', '.mkv', '.mov', '.m4v'}

def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=60, **kwargs)

def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False))
    temporary.replace(path)

def preview(path):
    stat = path.stat()
    digest = hashlib.sha256(f'{path}:{stat.st_mtime_ns}:{stat.st_size}'.encode()).hexdigest()
    target = CACHE / (digest + '.jpg')
    if not target.exists():
        run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(path), '-frames:v', '1',
             '-vf', 'scale=480:270:force_original_aspect_ratio=decrease', str(target)],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    return target

def color_mode():
    try: mode = (STATE / 'mode').read_text().strip()
    except OSError: mode = 'dark'
    return mode if mode in ('dark', 'light') else 'dark'

def current():
    try: return json.loads((STATE / 'wallpaper.json').read_text())
    except (OSError, ValueError): return {}

def listing():
    entries = []
    # Natural order: 2.png before 10.png.
    natural = lambda path: [int(part) if part.isdigit() else part for part in re.split(r'(\d+)', path.name.lower())]
    for path in sorted(ROOT.rglob('*'), key=natural):
        if not path.is_file() or path.suffix.lower() not in IMAGES | VIDEOS: continue
        try:
            thumb = preview(path)
            entries.append(dict(path=str(path), name=path.name, preview=thumb.as_uri(), video=path.suffix.lower() in VIDEOS))
        except (OSError, subprocess.SubprocessError): continue
    return dict(entries=entries, current=current().get('path', ''), matugen=bool(shutil.which('matugen')))

def stop_video():
    pid_file = STATE / 'mpvpaper.pid'
    try:
        pid = int(pid_file.read_text())
        command = Path(f'/proc/{pid}/cmdline').read_bytes()
        if b'mpvpaper' in command and str(STATE / 'mpvpaper.sock').encode() in command:
            os.kill(pid, signal.SIGTERM)
    except (OSError, ValueError): pass
    pid_file.unlink(missing_ok=True)

def start_video(path):
    try:
        pid = int((STATE / 'mpvpaper.pid').read_text())
        command = Path(f'/proc/{pid}/cmdline').read_bytes()
        if b'mpvpaper' in command and str(STATE / 'mpvpaper.sock').encode() in command and str(path).encode() in command:
            return
    except (OSError, ValueError): pass
    stop_video()
    with (STATE / 'mpvpaper.log').open('ab') as log:
        process = subprocess.Popen(['mpvpaper', '-p', '-a', 'FULL', '-o',
            'no-audio loop-file=inf input-ipc-server=' + str(STATE / 'mpvpaper.sock'),
            'ALL', str(path)], stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
    (STATE / 'mpvpaper.pid').write_text(str(process.pid))

def set_wallpaper(alias, wait_for_startup=False):
    # Restart a missing wallpaper daemon, including after a failed session start.
    probe = subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'hyprpaper'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if probe.returncode != 0:
        with (STATE / 'hyprpaper.log').open('ab') as log:
            subprocess.Popen(['hyprpaper'], stdin=subprocess.DEVNULL,
                             stdout=log, stderr=log, start_new_session=True)
    deadline = time.monotonic() + (12 if wait_for_startup else 5)
    while True:
        try:
            monitors = json.loads(subprocess.run(['hyprctl', 'monitors', '-j'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=3).stdout)
            if not monitors:
                raise ValueError('Нет подключённых мониторов')
            # Explicit targets also update outputs that already have a specific wallpaper.
            for monitor in monitors:
                result = subprocess.run(['hyprctl', 'hyprpaper', 'wallpaper',
                    monitor['name'] + ',' + str(alias) + ',cover'],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=3)
            return result
        except (subprocess.SubprocessError, OSError):
            if time.monotonic() >= deadline: raise
            time.sleep(0.3)

def apply(path, generate_palette=True, wait_for_startup=False):
    path = Path(path).resolve()
    if not path.is_file() or ROOT.resolve() not in path.parents or path.suffix.lower() not in IMAGES | VIDEOS:
        raise ValueError('Выбери изображение или видео из ~/Pictures/Wallpapers')
    thumb = preview(path)
    video = path.suffix.lower() in VIDEOS
    palette = CACHE.parent / 'colors.pending.json'
    generated = False
    if generate_palette and shutil.which('matugen'):
        palette.unlink(missing_ok=True)
        run(['matugen', '-c', str(BASE / 'matugen.toml'), '-m', color_mode(), '--source-color-index', '0',
             'image', str(thumb)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        colors = json.loads(palette.read_text())
        if colors.pop('mode', None) not in ('dark', 'light') or not all(
                isinstance(value, str) and len(value) == 7 and value.startswith('#') for value in colors.values()):
            raise ValueError('Matugen вернул некорректную палитру')
        generated = True
    # Hyprpaper's IPC uses commas as separators. A cache alias keeps arbitrary
    # filenames out of both IPC syntax and the persisted configuration.
    still = thumb if video else path
    alias = CACHE / (hashlib.sha256((str(still) + thumb.name).encode()).hexdigest() + still.suffix.lower())
    if not alias.exists(): alias.symlink_to(still)
    set_wallpaper(alias, wait_for_startup)
    if video: start_video(path)
    else: stop_video()
    config = HOME / '.config/hypr/hyprpaper.conf'
    backup = config.with_suffix('.conf.bak-before-picker')
    if config.exists() and not backup.exists(): shutil.copy2(config, backup)
    temporary = config.with_suffix('.conf.tmp')
    temporary.write_text(f'splash = false\nipc = true\nwallpaper {{\n    monitor =\n    path = {alias}\n    fit_mode = cover\n}}\n')
    temporary.replace(config)
    write_json(STATE / 'wallpaper.json', dict(path=str(path), video=video, preview=str(thumb)))
    if generated:
        shutil.copy2(palette, STATE / 'colors.json')
        palette.replace(CACHE.parent / 'colors.json')
    elif not generate_palette and (STATE / 'colors.json').exists():
        shutil.copy2(STATE / 'colors.json', palette)
        palette.replace(CACHE.parent / 'colors.json')
    if generated:
        # Optional application integrations must not undo the wallpaper.
        try:
            run([sys.executable, str(BASE / 'theme_sync.py'), color_mode()], stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE)
        except (OSError, subprocess.SubprocessError) as error:
            print('Application theme synchronization failed: ' + str(error), file=sys.stderr)
    else:
        # Without a new palette theme_sync.py does not run; the login screen still gets the wallpaper.
        try:
            run([sys.executable, str(BASE / 'greeter_sync.py')], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        except (OSError, subprocess.SubprocessError) as error:
            print('Login screen synchronization failed: ' + str(error), file=sys.stderr)
    return dict(path=str(path), message='Обои и цвета обновлены' if generated else 'Обои обновлены. Для смены цветов установи matugen: sudo pacman -S matugen')

def set_mode(mode):
    if mode not in ('dark', 'light'): raise ValueError('Режим: dark или light')
    selected = current()
    if not shutil.which('matugen'): raise ValueError('Для смены темы установи matugen: sudo pacman -S matugen')
    if not selected.get('path') or not Path(selected['path']).is_file():
        raise ValueError('Сначала выбери обои: палитра строится по ним')
    previous = color_mode()
    (STATE / 'mode').write_text(mode)
    try: apply(selected['path'])
    except BaseException:
        (STATE / 'mode').write_text(previous)
        raise
    return dict(mode=mode, path=selected['path'], message='Светлая тема' if mode == 'light' else 'Тёмная тема')

def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)
    action = sys.argv[1]
    with (STATE / 'wallpaper.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == 'list': print(json.dumps(listing(), ensure_ascii=False))
        elif action == 'apply': print(json.dumps(apply(sys.argv[2]), ensure_ascii=False))
        elif action == 'mode':
            print(json.dumps(set_mode(sys.argv[2]), ensure_ascii=False))
        elif action == 'restore':
            selected = current()
            if selected.get('path') and Path(selected['path']).is_file():
                apply(selected['path'], generate_palette=False, wait_for_startup=True)

if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        detail = getattr(error, 'stderr', b'') or getattr(error, 'stdout', b'') or b''
        print(detail.decode('utf-8', 'replace').strip() or str(error), file=sys.stderr)
        sys.exit(1)
