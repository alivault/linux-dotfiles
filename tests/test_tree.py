"""The file tree that nix/home.nix links (home/) and the seeds (seed/)."""
import os
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent
HOME = ROOT / 'home'
SEED = ROOT / 'seed'

# Apps write these: a link would be replaced or read-only. Seeds only.
APP_WRITTEN = ('.config/oasis/', '.pi/agent/settings.json', '.claude/settings.json',
               '.config/voxtype/config.toml')
# Oasis's own home-manager module links the session units.
OASIS_OWNS = re.compile(r'^\.config/systemd/user/(oasis[^/]*\.service|oasis\.service\.d/|voxtype\.service\.d/oasis\.conf)')
CHEZMOI = re.compile(r'(^|/)(dot_|private_|executable_|create_|modify_|symlink_|run_|exact_|readonly_)|\.tmpl$')
EXECUTABLE = ('.claude/hooks/herdr-agent-state.sh', '.config/herdr/move-pane.sh', '.local/bin/obsidian',
              '.local/share/agent-guard/bin/rm')


def files(root):
    return sorted(str(p.relative_to(root)) for p in root.rglob('*') if p.is_file())


class TreeTests(unittest.TestCase):
    def test_plain_names(self):
        for name in files(HOME) + files(SEED):
            self.assertIsNone(CHEZMOI.search(name), f'chezmoi name: {name}')

    def test_app_written_files_are_seeds_only(self):
        for name in files(HOME):
            self.assertFalse(name.startswith(APP_WRITTEN), f'{name} is written by its app: put it in seed/')

    def test_no_file_is_linked_and_seeded(self):
        self.assertFalse(set(files(HOME)) & set(files(SEED)))

    def test_oasis_owns_its_units(self):
        for name in files(HOME):
            self.assertIsNone(OASIS_OWNS.search(name), f'{name}: Oasis links it (nix/modules/home/oasis.nix)')

    def test_scripts_are_executable(self):
        for name in EXECUTABLE:
            self.assertTrue(os.access(HOME / name, os.X_OK), f'{name}: chmod +x and git update-index --chmod=+x')

    def test_shared_agent_rules_exist(self):
        # nix/home.nix links ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md to it.
        self.assertTrue((HOME / '.pi/agent/AGENTS.md').is_file())
        module = (ROOT / 'nix/home.nix').read_text()
        self.assertIn('link ".pi/agent/AGENTS.md"', module)


if __name__ == '__main__':
    unittest.main()
