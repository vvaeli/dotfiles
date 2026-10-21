#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=15, **kwargs)

def image_type(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n'): return 'png', 'image/png'
    if data.startswith(b'\xff\xd8\xff'): return 'jpg', 'image/jpeg'
    if data.startswith((b'GIF87a', b'GIF89a')): return 'gif', 'image/gif'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP': return 'webp', 'image/webp'
    if data.startswith(b'BM'): return 'bmp', 'image/bmp'
    return '', ''

def decode(entry_id):
    if not entry_id.isdecimal(): raise ValueError('Invalid clipboard entry')
    return run(['cliphist', 'decode'], input=entry_id.encode(), stdout=subprocess.PIPE).stdout

def main():
    if sys.argv[1] == 'copy':
        data = decode(sys.argv[2])
        _, mime = image_type(data)
        run(['wl-copy', '--type', mime or 'text/plain;charset=utf-8'], input=data)
        return
    cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'md3/clipboard'
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(cache, 0o700)
    rows = run(['cliphist', '-preview-width', '10000', 'list'], stdout=subprocess.PIPE).stdout.decode('utf-8', 'replace').splitlines()
    entries, retained = [], set()
    for row in rows:
        entry_id, sep, text = row.partition('\t')
        if not sep or not entry_id.isdecimal(): continue
        entry = dict(id=entry_id, text=text, kind='link' if text.startswith(('https://', 'http://')) else 'text', image='')
        if '[[ binary data' in text:
            data = decode(entry_id)
            extension, _ = image_type(data)
            image = None
            if extension and len(data) <= 16 * 1024 * 1024:
                digest = hashlib.sha256(data).hexdigest()[:20]
                image = cache / (entry_id + '-' + digest + '.' + extension)
                if not image.exists():
                    image.write_bytes(data)
                    image.chmod(0o600)
            if image:
                entry.update(kind='image', image=image.as_uri(), text='Изображение · ' + text.replace('[[ binary data ', '').replace(' ]]', ''))
                retained.add(image.name)
            else:
                entry['kind'] = 'file'
        entries.append(entry)
    for file in cache.iterdir():
        if file.is_file() and file.name not in retained: file.unlink()
    print(json.dumps(entries, ensure_ascii=False))

if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
