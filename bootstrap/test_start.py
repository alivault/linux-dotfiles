import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent


class StartTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.source = self.home / '.local/share/chezmoi'
        self.source.mkdir(parents=True)
        (self.source / '.git').mkdir()
        self.log = self.home / 'calls'
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin', DOTFILES_REF='a' * 40,
                        CALL_LOG=str(self.log), FAKE_ORIGIN='https://github.com/alivault/linux-dotfiles.git', FAKE_BRANCH='main')
        self.stub('id', 'echo 1000')
        self.stub('pacman', 'exit 0')
        self.stub('git', '''case "$*" in
          *'status --porcelain'*) printf '%s' "${FAKE_STATUS:-}" ;;
          *'config --get remote.origin.url'*) printf '%s' "$FAKE_ORIGIN" ;;
          *'branch --show-current'*) printf '%s' "$FAKE_BRANCH" ;;
          *) echo "git $*" >> "$CALL_LOG"; exit 90 ;;
        esac''')
        # Substitute only the fixture OS identity; production has no environment bypass.
        script = (ROOT / 'start.sh').read_text().replace('. /etc/os-release', 'ID=arch')
        self.script = self.home / 'start.sh'
        self.script.write_text(script)

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def run_start(self):
        return subprocess.run(['sh', str(self.script)], env=self.env, capture_output=True, text=True)

    def assert_refused(self, text):
        result = self.run_start()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(text, result.stderr)
        self.assertFalse(self.log.exists(), 'Refusal must precede git fetch or clone')

    def test_dirty_checkout(self):
        self.env['FAKE_STATUS'] = ' M local-file'
        self.assert_refused('Dirty checkout')

    def test_unexpected_remote(self):
        self.env['FAKE_ORIGIN'] = 'https://example.com/another-project.git'
        self.assert_refused('Unexpected source remote')

    def test_development_branch(self):
        self.env['FAKE_BRANCH'] = 'migration/arch-niri-noctalia'
        self.assert_refused('Development branch')

    def test_mutable_ref_and_root(self):
        self.env['DOTFILES_REF'] = 'main'
        self.assert_refused('reviewed DOTFILES_REF')
        self.env['DOTFILES_REF'] = 'a' * 40
        self.stub('id', 'echo 0')
        self.assert_refused('not root')

    def test_plan_has_no_provisioning_side_effects(self):
        result = subprocess.run(['bash', str(ROOT / 'setup.sh'), '--plan'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('No automatic service restarts', result.stdout)
        self.assertFalse(self.log.exists())

    def test_action_argument_errors_precede_privilege_requests(self):
        self.stub('pkexec', 'echo unexpected >> "$CALL_LOG"; exit 90')
        for args in [('packages', '--help'), ('system', '--apply', '--unexpected'), ('login', '--apply', '--unexpected')]:
            result = subprocess.run(['bash', str(ROOT / 'provision.sh'), *args], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
