#!/usr/bin/env python3
"""Find Kitty clients actually connected to this Herdr session (not stale env)."""
import json
import os
from pathlib import Path
import re
import subprocess


def run(*args):
    return subprocess.check_output(args, text=True, timeout=5)


def client_pids(output, socket_path):
    path = Path(socket_path)
    client_socket = str(path.with_name(path.stem + "-client.sock"))
    rows = [line.split(None, 8) for line in output.splitlines()]
    peers = {r[7] for r in rows if len(r) == 9 and r[4] == client_socket}
    return {int(pid) for r in rows if len(r) == 9 and r[5] in peers
            for pid in re.findall(r"pid=(\d+)", r[8])}


def ancestors(pid):
    seen = set()
    while pid > 1 and pid not in seen:
        seen.add(pid)
        try:
            status = Path(f"/proc/{pid}/status").read_text()
            pid = int(re.search(r"^PPid:\s+(\d+)", status, re.M)[1])
        except (OSError, TypeError):
            break
    return seen


def find_window():
    socket_path = os.environ["HERDR_SOCKET_PATH"]
    pids = client_pids(run("ss", "-xnpH"), socket_path)
    parents = set().union(*(ancestors(pid) for pid in pids))
    windows = json.loads(run("niri", "msg", "--json", "windows"))
    matches = [w for w in windows if w.get("app_id") == "kitty" and w.get("pid") in parents]
    # Multiple OS windows in one Kitty process cannot be disambiguated by PID.
    # Fail safely rather than raising an unrelated window.
    matches = [w for w in matches if sum(x.get("pid") == w["pid"] for x in windows) == 1]
    if not matches:
        raise RuntimeError("No unambiguous Niri Kitty window attached to this Herdr session")
    return max(matches, key=lambda w: (w.get("is_focused", False),
                                      (w.get("focus_timestamp") or {}).get("secs", 0)))


if __name__ == "__main__":
    print(find_window()["id"])
