#!/usr/bin/env python3
"""Audio spectrum for the player menu: records what the default output plays (its monitor)
through pw-record and prints one line of BARS levels (0-100) about 60 times a second.
Runs only while the menu is open; Quickshell stops it by closing the process.
Usage: visualizer.py [bars]"""
import ctypes, signal, subprocess, sys
import numpy as np

BARS = int(sys.argv[1]) if len(sys.argv) > 1 else 48
RATE, HOP, WINDOW = 44100, 735, 4096          # 735 samples = 60 lines per second
LOW, HIGH = 40.0, 16000.0

recorder = subprocess.Popen(
    ['pw-record', '-P', '{ stream.capture.sink=true node.name=md3-visualizer node.description="MD3 visualizer" }',
     '--format', 'f32', '--channels', '1', '--rate', str(RATE), '--latency', f'{HOP}/{RATE}', '--raw', '-'],
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    # pw-record goes away with this script even when it is killed outright.
    preexec_fn=lambda: ctypes.CDLL(None).prctl(1, signal.SIGTERM))

# Log-spaced bands; each band averages its FFT bins, at least one bin wide.
freqs = np.fft.rfftfreq(WINDOW, 1 / RATE)
edges = np.geomspace(LOW, HIGH, BARS + 1)
bins = []
for lo, hi in zip(edges[:-1], edges[1:]):
    idx = np.nonzero((freqs >= lo) & (freqs < hi))[0]
    if idx.size == 0: idx = np.array([np.argmin(np.abs(freqs - (lo + hi) / 2))])
    bins.append(idx)
# Treble carries less energy; tilt it up so the bars stay balanced across the range.
tilt = np.linspace(0.85, 1.9, BARS)
hann = np.hanning(WINDOW).astype(np.float32)
ring = np.zeros(WINDOW, dtype=np.float32)
levels = np.zeros(BARS)
peak = 1e-3

try:
    while True:
        chunk = recorder.stdout.read(HOP * 4)
        if not chunk or len(chunk) < HOP * 4: break
        samples = np.frombuffer(chunk, dtype=np.float32)
        ring = np.roll(ring, -HOP); ring[-HOP:] = samples
        spectrum = np.abs(np.fft.rfft(ring * hann))
        bands = np.array([spectrum[i].mean() for i in bins]) * tilt
        bands = np.log1p(bands * 4)
        # Auto gain: follows loud passages fast and decays slowly, so quiet tracks still move.
        peak = max(peak * 0.995, float(bands.max()), 0.35)
        target = np.clip(bands / peak, 0, 1)
        # Fast attack, smooth fall.
        levels = np.where(target > levels, levels + (target - levels) * 0.65, levels + (target - levels) * 0.18)
        if float(np.sqrt(np.mean(samples ** 2))) < 1e-4: levels *= 0.85
        sys.stdout.write(' '.join(str(int(v * 100)) for v in levels) + '\n')
        sys.stdout.flush()
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    recorder.terminate()
