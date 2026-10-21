#!/usr/bin/env python3
"""List NetworkManager APs as JSON; reads state without changing connections."""
import json
import os
import subprocess
import sys
from metrics import split_nm


def run(args):
    result = subprocess.run(['nmcli', *args], capture_output=True, text=True,
                            timeout=18, env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'NetworkManager недоступен')
    return result.stdout.strip()


def parse_networks(text):
    by_ssid = {}
    for line in text.splitlines():
        row = split_nm(line)
        if len(row) != 5 or not row[1]:
            continue
        try:
            signal = int(row[2])
        except ValueError:
            continue
        ap = {'ssid': row[1], 'active': row[0] == '*', 'signal': signal,
              'security': row[3], 'bssid': row[4]}
        old = by_ssid.get(ap['ssid'])
        if old is None or (ap['active'], ap['signal']) > (old['active'], old['signal']):
            by_ssid[ap['ssid']] = ap
    return sorted(by_ssid.values(), key=lambda ap: (not ap['active'], -ap['signal'], ap['ssid']))


def scan(rescan=False):
    devices = [split_nm(line) for line in run(['-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status']).splitlines()]
    wifi = [d for d in devices if len(d) == 3 and d[1] == 'wifi']
    enabled = run(['radio', 'wifi']) == 'enabled'
    device = next((d[0] for d in wifi if d[2] == 'connected'), wifi[0][0] if wifi else '')
    networks = []
    if device and enabled:
        networks = parse_networks(run(['--wait', '12', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY,BSSID',
                                       'device', 'wifi', 'list', 'ifname', device,
                                       '--rescan', 'yes' if rescan else 'no']))
    return {'available': bool(wifi), 'enabled': enabled, 'device': device, 'networks': networks, 'error': ''}


if __name__ == '__main__':
    try:
        data = scan('--rescan' in sys.argv)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        data = {'available': False, 'enabled': False, 'device': '', 'networks': [], 'error': str(error)}
    print(json.dumps(data, ensure_ascii=False))
