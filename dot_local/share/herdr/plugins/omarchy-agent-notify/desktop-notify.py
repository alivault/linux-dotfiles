#!/usr/bin/env python3
"""Wait for desktop actions outside Herdr's short-lived event hook."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    pane, title, body, identity = sys.argv[1:]
    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")
    proc = subprocess.Popen([
        "notify-send", "--app-name=Herdr", "--icon=kitty", "--expire-time=0",
        "--action=default=Open agent", "--", title, body,
    ], stdout=subprocess.PIPE, text=True)
    try:
        output, _ = proc.communicate(timeout=86400)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        return
    if proc.returncode or output.strip() not in ("default", "open"):
        return
    current = json.loads(subprocess.check_output(
        [herdr, "agent", "get", pane], text=True, timeout=5))["result"]["agent"]
    expected = json.loads(identity)
    if any(current.get(key) != value for key, value in expected.items()):
        print("Ignoring notification for an agent that exited or was replaced", file=sys.stderr)
        return
    subprocess.run([str(Path(__file__).with_name("focus-agent.sh")), pane,
                    os.environ["HERDR_SOCKET_PATH"], herdr], check=True, timeout=10)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--spawn"]:
        state = Path(os.environ.get("HERDR_PLUGIN_STATE_DIR",
                     str(Path.home() / ".local/state/herdr/omarchy-agent-notify")))
        state.mkdir(parents=True, exist_ok=True)
        with (state / "desktop-notify.log").open("a") as log:
            subprocess.Popen([sys.executable, __file__, *sys.argv[2:]],
                             stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                             start_new_session=True, close_fds=True)
    else:
        main()
