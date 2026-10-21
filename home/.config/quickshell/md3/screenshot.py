#!/usr/bin/env python3
"""ShareX-style screenshots for the md3 shell.

freeze             capture every monitor at once; the shell shows it frozen while selecting
crop X Y W H [edit] cut a rectangle (global layout pixels) out of the frozen capture
screen [edit]      capture all monitors immediately
active [edit]      capture the focused window immediately

Every capture is saved to ~/Pictures/Screenshots, copied to the clipboard, announced with
the shutter sound and a notification with a preview: clicking it opens the image.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from PIL import Image

HOME = Path.home()
BASE = Path(__file__).resolve().parent
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/md3-{os.getuid()}')) / 'md3-screenshot'
FROZEN = RUNTIME / 'frozen.ppm'
DESTINATION = HOME / 'Pictures/Screenshots'
SATTY_CONFIG = HOME / '.config/hypr/scripts/satty-sharex.toml'
SOUND = Path('/usr/share/sounds/freedesktop/stereo/camera-shutter.oga')


def hyprctl(*args):
    return json.loads(subprocess.run(['hyprctl', '-j', *args], capture_output=True, check=True, text=True).stdout)


def layout():
    monitors = [m for m in hyprctl('monitors') if not m.get('disabled')]
    # Logical size: a rotated or scaled monitor covers width/scale × height/scale of the layout.
    for m in monitors:
        w, h = m['width'] / m['scale'], m['height'] / m['scale']
        if m.get('transform', 0) % 2: w, h = h, w
        m['logicalWidth'], m['logicalHeight'] = round(w), round(h)
    return monitors


def visible_windows(monitors):
    active = {m['activeWorkspace']['id'] for m in monitors}
    special = {m['specialWorkspace']['id'] for m in monitors if m.get('specialWorkspace', {}).get('id')}
    windows = []
    for c in hyprctl('clients'):
        if c.get('mapped') is False or c.get('hidden') or c['size'][0] <= 0 or c['size'][1] <= 0: continue
        workspace = c['workspace']['id']
        if not (c.get('pinned') or workspace in active or workspace in special): continue
        # Topmost first: special workspace, fullscreen, pinned, floating, then most recently focused.
        rank = (0 if workspace in special else 1, 0 if c.get('fullscreen') else 1, 0 if c.get('pinned') else 1,
                0 if c.get('floating') else 1, c.get('focusHistoryID', 99))
        windows.append((rank, {'x': c['at'][0], 'y': c['at'][1], 'width': c['size'][0], 'height': c['size'][1],
                               'title': c.get('title') or c.get('class') or ''}))
    return [w for _, w in sorted(windows, key=lambda item: item[0])]


def freeze():
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    monitors = layout()
    # PPM: no compression, the whole layout is on disk in ~40 ms.
    subprocess.run(['grim', '-t', 'ppm', str(FROZEN)], check=True)
    left = min(m['x'] for m in monitors)
    top = min(m['y'] for m in monitors)
    right = max(m['x'] + m['logicalWidth'] for m in monitors)
    with FROZEN.open('rb') as image:  # P6 header: magic, width height, maxval
        header = image.read(64).split()
    scale = int(header[1]) / (right - left)
    info = {
        'path': str(FROZEN), 'originX': left, 'originY': top, 'scale': scale,
        'monitors': [{'name': m['name'], 'x': m['x'], 'y': m['y'], 'width': m['logicalWidth'], 'height': m['logicalHeight']}
                     for m in monitors],
        'windows': visible_windows(monitors),
        'cursor': hyprctl('cursorpos'),
    }
    (RUNTIME / 'frozen.json').write_text(json.dumps(info))
    print(json.dumps(info, ensure_ascii=False))


def output_path():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    stem = time.strftime('%Y-%m-%d_%H-%M-%S')
    path, suffix = DESTINATION / f'{stem}.png', 0
    while path.exists() or path.is_symlink():
        suffix += 1
        path = DESTINATION / f'{stem}-{suffix}.png'
    return path


def detached(args):
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def finish(path, edit):
    if SOUND.exists() and shutil.which('pw-play'): detached(['pw-play', str(SOUND)])
    if edit and shutil.which('satty'):
        subprocess.run(['satty', '--config', str(SATTY_CONFIG), '--filename', str(path), '--fullscreen',
                        '--output-filename', str(path)], stdin=subprocess.DEVNULL)
    with path.open('rb') as image:
        subprocess.run(['wl-copy', '--type', 'image/png'], stdin=image, check=True)
    image = Image.open(path)
    # Like ShareX's toast: preview, a click opens the image, a second button opens the folder.
    notify = ['notify-send', '-a', 'Скриншот', '-i', 'camera-photo', '-h', f'string:image-path:{path}',
              '-A', 'default=Открыть', '-A', 'folder=Открыть папку',
              'Скриншот сохранён', f'{path.name} · {image.width}×{image.height}\nСкопирован в буфер обмена']
    script = 'case "$(' + ' '.join(map(sh_quote, notify)) + ')" in ' \
             f'default) xdg-open {sh_quote(str(path))} ;; folder) xdg-open {sh_quote(str(path.parent))} ;; esac'
    detached(['sh', '-c', script])
    print(path)


def sh_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"


def crop(x, y, width, height, edit, layers):
    info = json.loads((RUNTIME / 'frozen.json').read_text())
    s = info['scale']
    to_pixels = lambda gx, gy: (round((gx - info['originX']) * s), round((gy - info['originY']) * s))
    path = output_path()
    with Image.open(FROZEN) as frozen:
        image = frozen.convert('RGBA') if layers else frozen
        # Annotations drawn on each monitor's overlay, rendered at its logical size.
        monitors = {m['name']: m for m in info['monitors']}
        for name, layer_path in layers:
            monitor = monitors.get(name)
            if not monitor: continue
            with Image.open(layer_path) as layer:
                size = (round(monitor['width'] * s), round(monitor['height'] * s))
                layer = layer.convert('RGBA')
                if layer.size != size: layer = layer.resize(size, Image.LANCZOS)
                image.alpha_composite(layer, to_pixels(monitor['x'], monitor['y']))
            Path(layer_path).unlink(missing_ok=True)
        image.crop((*to_pixels(x, y), *to_pixels(x + width, y + height))).convert('RGB').save(path, compress_level=3)
    FROZEN.unlink(missing_ok=True)
    finish(path, edit)


def capture(geometry, edit):
    path = output_path()
    subprocess.run(['grim', *(['-g', geometry] if geometry else []), str(path)], check=True)
    finish(path, edit)


def main():
    action, rest = sys.argv[1], sys.argv[2:]
    edit = 'edit' in rest
    if action == 'freeze':
        freeze()
    elif action == 'crop':
        layers = [tuple(arg[6:].split('=', 1)) for arg in rest if arg.startswith('layer:')]
        crop(*map(float, rest[:4]), edit, layers)
    elif action == 'screen':
        capture(None, edit)
    elif action == 'active':
        window = hyprctl('activewindow')
        if not window.get('size'): raise ValueError('Нет активного окна')
        capture('{},{} {}x{}'.format(*window['at'], *window['size']), edit)
    else:
        raise ValueError(f'Неизвестное действие: {action}')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:  # Reported in the shell and as a notification.
        subprocess.run(['notify-send', '-a', 'Скриншот', '-u', 'critical', 'Ошибка скриншота', str(error)])
        print(error, file=sys.stderr)
        sys.exit(1)
