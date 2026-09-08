import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('install_system', Path(__file__).with_name('install-system.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DestinationTests(unittest.TestCase):
    def test_no_docker_configuration_is_provisioned(self):
        self.assertFalse(any('docker' in name for name in module.COMMON))
        resolver = module.ROOT / 'system-files/etc/systemd/resolved.conf.d/99-standalone.conf'
        self.assertNotIn('172.17.', resolver.read_text())

    def test_missing_and_identical_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config'
            module.check_destination(path, b'expected')
            path.write_bytes(b'expected')
            module.check_destination(path, b'expected')

    def test_custom_configuration_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config'
            path.write_bytes(b'custom')
            with self.assertRaises(RuntimeError):
                module.check_destination(path, b'expected')
            self.assertEqual(path.read_bytes(), b'custom')

    def test_symlink_and_symlink_parent_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'link'
            path.symlink_to(Path(directory) / 'missing')
            for target in [path, path / 'child']:
                with self.assertRaises(RuntimeError):
                    module.check_destination(target, b'expected')


if __name__ == '__main__':
    unittest.main()
