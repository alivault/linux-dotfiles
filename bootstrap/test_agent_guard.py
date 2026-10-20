"""The agent rm guard (dot_local/share/agent-guard/bin/executable_rm).

The real rm is a stub here (AGENT_GUARD_REAL_RM): a refused call must never
reach it, and an allowed one reaches it with its arguments unchanged.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

GUARD = Path(__file__).resolve().parent.parent / 'dot_local/share/agent-guard/bin/executable_rm'


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / 'home'
        for d in ('code/alniac/.git', 'code/scratch/build', 'code/scratch/repo/.git', '.config/alniac', '.local/share/x', '.pico/worktrees/w'):
            (self.home / d).mkdir(parents=True)
        self.log = Path(self.tmp.name) / 'ran'
        stub = Path(self.tmp.name) / 'rm-stub'
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$RAN_LOG"\n')
        stub.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), AGENT_GUARD_REAL_RM=str(stub), RAN_LOG=str(self.log))

    def rm(self, *args):
        result = subprocess.run([os.environ.get('GUARD_BASH', 'bash'), str(GUARD), *args], env=self.env, capture_output=True, text=True,
                                cwd=self.home)
        ran = self.log.read_text().split('\n')[:-1] if self.log.exists() else None
        if self.log.exists():
            self.log.unlink()
        return result, ran

    def assert_refused(self, *args):
        result, ran = self.rm(*args)
        self.assertNotEqual(result.returncode, 0, args)
        self.assertIn('agent guard', result.stderr)
        self.assertIsNone(ran, 'refused before the real rm')

    def test_the_2026_10_19_command(self):
        # rm -rf "$T"/* with T empty: the shell expands /* first.
        self.assert_refused('-rf', *sorted(str(p) for p in Path('/').iterdir()))
        self.assert_refused('-rf', '/')

    def test_home_and_its_top_level(self):
        h = self.home
        self.assert_refused('-rf', str(h))
        self.assert_refused('-rf', f'{h}/')
        self.assert_refused('-rf', str(h / 'code'))
        self.assert_refused('-r', str(h / '.config'))
        self.assert_refused('-f', str(h / '.bashrc'))
        self.assert_refused('-rf', str(h / 'code' / 'scratch'), str(h / '.config' / 'alniac'))
        self.assert_refused('-rf', str(h / '.local' / 'share' / 'x'))
        self.assert_refused('-rf', 'code/../code')          # relative, normalized

    def test_git_repositories_need_more_than_rm_r(self):
        repo = self.home / 'code' / 'scratch' / 'repo'
        self.assert_refused('-rf', str(repo))
        self.assert_refused('--recursive', str(repo))
        result, ran = self.rm('-f', str(repo / 'file'))
        self.assertEqual((result.returncode, ran), (0, ['-f', str(repo / 'file')]), 'a file in it is fine')

    def test_ordinary_paths_reach_the_real_rm(self):
        h = self.home
        for args in (['-rf', str(h / 'code' / 'scratch' / 'build')], ['-rf', '/tmp/some-dir'],
                     ['-f', str(h / '.pico' / 'worktrees' / 'w' / 'file')], ['-rf', '--', 'code/scratch/-odd-name']):
            result, ran = self.rm(*args)
            self.assertEqual(result.returncode, 0, (args, result.stderr))
            self.assertEqual(ran, args, 'arguments unchanged')


if __name__ == '__main__':
    unittest.main()
