"""Offline tests: no network, packages, or real home changes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('installer', Path(__file__).with_name('install-tools.py'))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def test_replace_running_style_binary_is_atomic_and_backed_up(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, dest = root / 'download', root / 'bin/tool'
            source.write_bytes(b'new')
            dest.parent.mkdir()
            dest.write_bytes(b'old')
            installer.deploy(source, dest, root / 'backup')
            self.assertEqual(dest.read_bytes(), b'new')
            self.assertEqual((root / 'backup/tool').read_bytes(), b'old')
            installer.deploy(source, dest, root / 'backup')
            self.assertEqual((root / 'backup/tool').read_bytes(), b'old')
            self.assertEqual(dest.stat().st_mode & 0o777, 0o755)

    def test_verified_cached_binary_needs_no_network(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(installer, 'HOME', Path(temp)):
            cached = Path(temp) / '.cache/standalone-tools/artifact'
            cached.parent.mkdir(parents=True)
            cached.write_bytes(b'fixture')
            data = {'repo': 'test/test', 'tag': 'v1', 'kind': 'binary',
                    'aarch64': ['artifact', installer.digest(cached)]}
            with patch.object(installer.urllib.request, 'urlopen', side_effect=AssertionError('network')):
                installer.install('tool', data, 'aarch64', Path(temp) / 'backup')
            self.assertEqual((Path(temp) / '.local/bin/tool').read_bytes(), b'fixture')

    def test_lock_has_pins_for_both_architectures(self):
        data = json.loads(Path(__file__).with_name('tools.lock.json').read_text())
        for tool in data.values():
            for arch in ['aarch64', 'x86_64']:
                self.assertRegex(tool[arch][1], r'^[a-f0-9]{64}$')
            self.assertTrue(tool['tag'].startswith('v'))


if __name__ == '__main__':
    unittest.main()
