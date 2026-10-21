#!/usr/bin/env python3
"""Read-only metrics stream for Quickshell; no shell expansion or extra packages."""
import json
import os
import shutil
import subprocess
import time
from pathlib import Path


def command(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=2, env={**os.environ, "LC_ALL": "C"})
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def cpu_sample():
    # Linux guest counters are already included in user/nice.
    values = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    return sum(values), values[3] + values[4]


def memory():
    values = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        values[key] = int(value.split()[0])
    total = values['MemTotal']
    used = total - values['MemAvailable']
    return {'ram': round(100 * used / total), 'ramUsed': round(used / 1048576, 1),
            'ramTotal': round(total / 1048576, 1)}


def split_nm(line):
    """Decode nmcli's escaped colon/backslash without corrupting SSIDs."""
    result, word, escaped = [], '', False
    for char in line:
        if escaped:
            word += char
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(word)
            word = ''
        else:
            word += char
    return result + [word]


def network():
    rows = [split_nm(line) for line in command(['nmcli', '-t', '-f',
            'DEVICE,TYPE,STATE,CONNECTION', 'device', 'status']).splitlines()]
    active = next((r for r in rows if len(r) >= 4 and r[2] == 'connected'
                   and r[1] in ('wifi', 'ethernet')), None)
    radio = command(['nmcli', 'radio', 'wifi'])
    signal = 0
    if active and active[1] == 'wifi':
        access_points = command(['nmcli', '-t', '-f', 'IN-USE,SIGNAL', 'device', 'wifi', 'list', '--rescan', 'no', 'ifname', active[0]])
        for line in access_points.splitlines():
            row = split_nm(line)
            if len(row) == 2 and row[0] == '*':
                try: signal = max(0, min(100, int(row[1])))
                except ValueError: pass
                break
    return {'networkAvailable': bool(rows), 'wifiEnabled': radio == 'enabled',
            'network': active[3] if active else 'Нет подключения',
            'networkType': active[1] if active else 'offline',
            'networkDevice': active[0] if active else '', 'wifiSignal': signal}


def brightness():
    for device in sorted(Path('/sys/class/backlight').glob('*')):
        try:
            maximum = int((device / 'max_brightness').read_text())
            current = int((device / 'brightness').read_text())
            if maximum:
                return {'brightnessAvailable': bool(shutil.which('brightnessctl')),
                        'brightness': current / maximum, 'brightnessDevice': device.name}
        except (OSError, ValueError):
            pass
    return {'brightnessAvailable': False, 'brightness': 0, 'brightnessDevice': ''}


def stream():
    previous = cpu_sample()
    net = network()
    tick = 0
    while True:
        current = cpu_sample()
        total = current[0] - previous[0]
        idle = current[1] - previous[1]
        cpu = round(100 * (total - idle) / total) if total else 0
        previous = current
        if tick % 4 == 0:
            net = network()
        stat = shutil.disk_usage(Path.home())
        data = {'cpu': cpu, 'disk': round(stat.used / stat.total * 100),
                'diskFree': round(stat.free / 1073741824, 1), **memory(), **net, **brightness()}
        print(json.dumps(data, ensure_ascii=False), flush=True)
        tick += 1
        time.sleep(2)


if __name__ == '__main__':
    try:
        stream()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
