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
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin',
                        XDG_CACHE_HOME=str(self.home / '.cache'), DOTFILES_REF='a' * 40,
                        CALL_LOG=str(self.log), FAKE_ORIGIN='https://github.com/alivault/linux-dotfiles.git',
                        FAKE_BRANCH='main')
        self.stub('id', 'echo 1000')
        self.stub('pacman', 'echo unexpected >> "$CALL_LOG"; exit 90')
        # An installed ALNIAC: a staged release and the ~/code/alniac checkout.
        self.alniac_version = self.home / '.local/share/alniac/current/bin/alniac-version'
        self.alniac_version.parent.mkdir(parents=True)
        self.alniac_version.write_text('#!/bin/sh\necho 20261019-alniac-01\n')
        self.alniac_version.chmod(0o755)
        (self.home / 'code/alniac/.git').mkdir(parents=True)
        self.stub('git', '''case "$*" in
          *'status --porcelain'*) printf '%s' "${FAKE_STATUS:-}" ;;
          *'config --get remote.origin.url'*) printf '%s' "$FAKE_ORIGIN" ;;
          *'branch --show-current'*) printf '%s' "$FAKE_BRANCH" ;;
          *) echo "git $*" >> "$CALL_LOG"; exit 90 ;;
        esac''')
        # Only the fixture substitutes OS identity; production has no bypass.
        script = (ROOT / 'start.sh').read_text().replace('. /etc/os-release', 'ID=arch')
        self.script = self.home / 'start.sh'
        self.script.write_text(script)

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def assert_refused(self, text):
        result = subprocess.run(['sh', str(self.script)], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(text, result.stderr)
        self.assertFalse(self.log.exists(), 'Refusal must precede fetch, install or provisioning')

    def test_dirty_checkout(self):
        self.env['FAKE_STATUS'] = ' M local-file'
        self.assert_refused('Dirty checkout')

    def test_unexpected_remote(self):
        self.env['FAKE_ORIGIN'] = 'https://example.com/other.git'
        self.assert_refused('Unexpected source remote')

    def test_development_branch(self):
        self.env['FAKE_BRANCH'] = 'feature/in-progress'
        self.assert_refused('Development branch')

    def test_mutable_ref_and_root(self):
        self.env['DOTFILES_REF'] = 'main'
        self.assert_refused('reviewed DOTFILES_REF')
        self.env['DOTFILES_REF'] = 'a' * 40
        self.stub('id', 'echo 0')
        self.assert_refused('not root')

    def test_alniac_required_before_checkout(self):
        self.alniac_version.unlink()
        self.assert_refused('requires ALNIAC')

    def test_existing_non_repository(self):
        (self.source / '.git').rmdir()
        self.assert_refused('Existing non-repository')

    def test_plans_have_no_side_effects(self):
        for shell, script in [('sh', self.script), ('/usr/bin/bash', ROOT / 'setup.sh')]:
            result = subprocess.run([shell, str(script), '--plan'], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('ALNIAC', result.stdout)
            self.assertFalse(self.log.exists())
            self.assertFalse((self.home / '.cache').exists())

    def test_bad_setup_arguments_before_side_effects(self):
        for args in [('--unexpected',), ('--apply', '--unexpected')]:
            result = subprocess.run(['/usr/bin/bash', str(ROOT / 'setup.sh'), *args], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
        self.assertFalse(self.log.exists())

    def test_unknown_provision_step_before_side_effects(self):
        result = subprocess.run(['/usr/bin/bash', str(ROOT / 'provision.sh'), 'preflight', 'not-a-step'],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unknown provisioning step', result.stderr)
        self.assertFalse(self.log.exists())

    def test_setup_rejects_missing_alniac_before_apply(self):
        self.stub('chezmoi', 'echo unexpected >> "$CALL_LOG"; exit 90')
        self.alniac_version.unlink()
        result = subprocess.run(['/usr/bin/bash', str(ROOT / 'setup.sh'), '--apply'],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires ALNIAC', result.stderr)
        self.assertFalse(self.log.exists())

    def test_setup_pipeline_with_stubbed_actions(self):
        self.stub('chezmoi', 'echo "chezmoi $*" >> "$CALL_LOG"')
        self.stub('bash', 'echo "bash $*" >> "$CALL_LOG"')
        result = subprocess.run(['/usr/bin/bash', str(ROOT / 'setup.sh'), '--apply'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertEqual(len(calls), 5)
        self.assertIn('chezmoi init --source', calls[0])
        self.assertIn('diff --exclude scripts', calls[1])
        self.assertIn('apply --exclude scripts', calls[2])
        self.assertIn('provision.sh', calls[3])
        self.assertIn('doctor.sh', calls[4])


if __name__ == '__main__':
    unittest.main()
