from pathlib import Path
import configparser
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent


class VoxtypeTests(unittest.TestCase):
    def test_recording_notifications_disabled(self):
        with (ROOT / 'dot_config/voxtype/config.toml').open('rb') as file:
            config = tomllib.load(file)
        self.assertEqual(config['state_file'], 'auto')
        self.assertFalse(config['output']['notification']['on_recording_start'])
        self.assertFalse(config['output']['notification']['on_recording_stop'])

    def test_service_privacy(self):
        config = configparser.ConfigParser()
        config.read(ROOT / 'dot_config/systemd/user/voxtype.service.d/privacy.conf')
        self.assertEqual(config['Service']['Environment'], 'RUST_LOG=warn')

    def test_journal_limits(self):
        config = configparser.ConfigParser()
        config.read(ROOT / 'bootstrap/files/journald-retention.conf')
        self.assertEqual(config['Journal']['SystemMaxUse'], '256M')
        self.assertEqual(config['Journal']['MaxRetentionSec'], '7day')

    def test_launcher_uses_omarchy(self):
        config = configparser.ConfigParser()
        config.read(ROOT / 'dot_local/share/applications/voxtype.desktop')
        self.assertEqual(config['Desktop Entry']['Exec'], 'omarchy voxtype config')
        self.assertEqual(config['Desktop Entry']['Terminal'], 'false')


if __name__ == '__main__':
    unittest.main()
