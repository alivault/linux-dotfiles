import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


window = load("niri-window")
notify = load("desktop-notify")


class WindowTests(unittest.TestCase):
    def test_session_socket_pair_not_other_session(self):
        rows = '''u_str ESTAB 0 0 /tmp/herdr-client.sock 101 * 102 users:(("herdr",pid=1,fd=3))
u_str ESTAB 0 0 * 102 * 101 users:(("herdr",pid=42,fd=4))
u_str ESTAB 0 0 /tmp/other-client.sock 201 * 202 users:(("herdr",pid=2,fd=3))
u_str ESTAB 0 0 * 202 * 201 users:(("herdr",pid=99,fd=4))'''
        self.assertEqual(window.client_pids(rows, "/tmp/herdr.sock"), {42})

    def resolve(self, windows):
        with patch.dict(os.environ, {"HERDR_SOCKET_PATH": "/tmp/herdr.sock"}), \
             patch.object(window, "client_pids", return_value={42}), \
             patch.object(window, "ancestors", return_value={42, 40, 10}), \
             patch.object(window, "run", side_effect=["", json.dumps(windows)]):
            return window.find_window()

    def test_kitty_through_shell_ancestry(self):
        result = self.resolve([{"id": 7, "pid": 10, "app_id": "kitty"},
                               {"id": 8, "pid": 11, "app_id": "kitty", "is_focused": True}])
        self.assertEqual(result["id"], 7)

    def test_no_attached_window_refuses_guess(self):
        with self.assertRaises(RuntimeError):
            self.resolve([{"id": 8, "pid": 11, "app_id": "kitty"}])

    def test_shared_kitty_pid_refuses_guess(self):
        with self.assertRaises(RuntimeError):
            self.resolve([{"id": 7, "pid": 10, "app_id": "kitty"},
                          {"id": 8, "pid": 10, "app_id": "kitty"}])


class ActionTests(unittest.TestCase):
    def action(self, action, replaced=False):
        identity = {"terminal_id": "term-test", "agent_session": {"value": "session-test"}}
        current = {**identity, "terminal_id": "replacement"} if replaced else identity
        proc = Mock(returncode=0)
        proc.communicate.return_value = (action, None)
        with patch.object(notify.sys, "argv", ["desktop-notify.py", "pane-test", "Pi", "body", json.dumps(identity)]), \
             patch.dict(os.environ, {"HERDR_SOCKET_PATH": "/tmp/herdr.sock"}), \
             patch.object(notify.subprocess, "Popen", return_value=proc), \
             patch.object(notify.subprocess, "check_output", return_value=json.dumps({"result": {"agent": current}})), \
             patch.object(notify.subprocess, "run") as focus:
            notify.main()
            return focus.call_args

    def test_body_click_focuses_original_pane_and_socket(self):
        args = self.action("default\n")[0][0]
        self.assertEqual(args[1:3], ["pane-test", "/tmp/herdr.sock"])

    def test_button_click(self):
        self.assertIsNotNone(self.action("open\n"))

    def test_dismissal_does_not_focus(self):
        self.assertIsNone(self.action(""))

    def test_replaced_agent_does_not_focus(self):
        self.assertIsNone(self.action("default\n", replaced=True))


if __name__ == "__main__":
    unittest.main()
