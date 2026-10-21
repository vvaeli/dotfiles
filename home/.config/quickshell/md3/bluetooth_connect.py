#!/usr/bin/env python3
"""Pair headphones with a live bluetoothctl agent, then trust and connect."""
import os
import pty
import re
import select
import subprocess
import sys
import time


def friendly_error(text):
    if "Authentication" in text:
        return "Сопряжение отклонено. Включи режим сопряжения на наушниках и повтори. " + text
    if "InProgress" in text:
        return "Подключение уже выполняется. Подожди и повтори. " + text
    return text


class Session:
    def __enter__(self):
        self.master, slave = pty.openpty()
        try:
            self.process = subprocess.Popen(["bluetoothctl", "--agent", "NoInputNoOutput"],
                stdin=slave, stdout=slave, stderr=slave,
                env={**os.environ, "LC_ALL": "C", "TERM": "dumb"})
        finally:
            os.close(slave)
        try:
            self.wait_for("Agent registered", 12)
        except Exception:
            self.__exit__()
            raise
        return self

    def wait_for(self, success, timeout):
        deadline = time.monotonic() + timeout
        output = ""
        while time.monotonic() < deadline:
            readable, _, _ = select.select([self.master], [], [], min(0.25, max(0, deadline-time.monotonic())))
            if readable:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    raise RuntimeError("Bluetooth-служба завершила соединение. " + output[-400:])
                output += chunk.decode(errors="replace")
                output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
                failure = re.search(r"(?:Failed to [^\r\n]+|Device [^\r\n]+ not available|No default controller available)", output)
                if failure:
                    raise RuntimeError(friendly_error(failure.group(0)))
                if success in output:
                    return
            if self.process.poll() is not None:
                raise RuntimeError("bluetoothctl завершился. " + output[-400:])
        raise RuntimeError("Устройство не ответило вовремя. Включи режим сопряжения и повтори.")

    def command(self, text, success, timeout=20):
        os.write(self.master, (text + "\n").encode())
        self.wait_for(success, timeout)

    def __exit__(self, *args):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        os.close(self.master)


def connect(action, address):
    with Session() as session:
        if action == "disconnect":
            session.command("disconnect " + address, "Successful disconnected")
            return
        if action == "pair":
            session.command("pair " + address, "Pairing successful", 45)
        session.command("trust " + address, "trust succeeded")
        session.command("connect " + address, "Connection successful", 35)


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("pair", "connect", "disconnect") or not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", sys.argv[2]):
        print("Некорректное устройство Bluetooth", file=sys.stderr)
        return 1
    try:
        connect(*sys.argv[1:])
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
