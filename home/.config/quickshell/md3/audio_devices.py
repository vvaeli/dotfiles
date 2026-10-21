#!/usr/bin/env python3
"""Discover PulseAudio-compatible PipeWire outputs and route playing streams."""
import json
import os
import subprocess
import sys
import time


def pactl(*args):
    result = subprocess.run(["pactl", *args], capture_output=True, text=True,
                            env={**os.environ, "LC_ALL": "C"}, timeout=5)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Аудиосервер недоступен")
    return result.stdout.strip()


def listing(kind):
    return json.loads(pactl("--format=json", "list", kind))


def a2dp_profile(card):
    profiles = card.get("profiles", {})
    entries = profiles.items() if isinstance(profiles, dict) else ((p["name"], p) for p in profiles)
    candidates = [(name, profile) for name, profile in entries
                  if "a2dp" in name.lower() and profile.get("available") != "no"]
    return max(candidates, key=lambda p: p[1].get("priority", 0), default=("", {}))[0]


def snapshot():
    sinks = listing("sinks")
    default = pactl("get-default-sink")
    cards = listing("cards")
    return {
        "outputs": [{"name": s["name"], "description": s.get("description") or s["name"],
                     "bluetooth": s["name"].startswith("bluez_output."),
                     "active": s["name"] == default} for s in sinks],
        "bluetoothCards": [{"name": c["name"],
                            "description": c.get("properties", {}).get("device.description", c["name"]),
                            "profile": a2dp_profile(c)} for c in cards
                           if c["name"].startswith("bluez_card.") and a2dp_profile(c)
                           and "a2dp" not in c.get("active_profile", "").lower()],
        "error": "",
    }


def select_output(name):
    # Resolve before changing anything: a disconnected output must not be selected.
    if not any(s["name"] == name for s in listing("sinks")):
        raise RuntimeError("Устройство отключилось. Обнови список и попробуй ещё раз.")
    pactl("set-default-sink", name)
    failures = []
    for stream in listing("sink-inputs"):
        try:
            pactl("move-sink-input", str(stream["index"]), name)
        except RuntimeError:
            # An application may stop between listing and moving its stream.
            if any(s["index"] == stream["index"] for s in listing("sink-inputs")):
                failures.append(str(stream["index"]))
    if failures:
        raise RuntimeError("Выход выбран, но часть приложений не переключилась. Перезапусти воспроизведение.")


def activate_bluetooth(name):
    card = next((c for c in listing("cards") if c["name"] == name), None)
    if card is None or not name.startswith("bluez_card."):
        raise RuntimeError("Bluetooth-наушники отключились")
    profile = a2dp_profile(card)
    if not profile:
        raise RuntimeError("Наушники не предоставляют профиль A2DP")
    pactl("set-card-profile", name, profile)
    for _ in range(20):
        sink = next((s for s in listing("sinks") if str(s.get("card")) == str(card["index"])), None)
        if sink:
            select_output(sink["name"])
            return
        time.sleep(0.15)
    raise RuntimeError("Аудиовыход ещё не появился. Проверь подключение наушников.")


def main():
    try:
        if len(sys.argv) == 1:
            print(json.dumps(snapshot(), ensure_ascii=False))
        elif len(sys.argv) == 3 and sys.argv[1] == "--select":
            select_output(sys.argv[2])
        elif len(sys.argv) == 3 and sys.argv[1] == "--bluetooth":
            activate_bluetooth(sys.argv[2])
        else:
            raise RuntimeError("Неизвестное действие")
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        if len(sys.argv) == 1:
            print(json.dumps({"outputs": [], "bluetoothCards": [], "error": str(error)}, ensure_ascii=False))
        else:
            print(str(error), file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
