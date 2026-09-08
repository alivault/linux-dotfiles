import json
from pathlib import Path
import subprocess
import unittest

MODIFIER = Path(__file__).resolve().parent.parent / 'dot_pi/agent/modify_private_settings.json'


def apply(data):
    return json.loads(subprocess.check_output(['sh', str(MODIFIER)], input=json.dumps(data), text=True))


class SettingsTests(unittest.TestCase):
    def test_fresh_defaults_and_idempotence(self):
        result = apply({})
        self.assertEqual(len(result['packages']), 5)
        self.assertEqual(apply(result), result)
        self.assertFalse(result['enableInstallTelemetry'])
        self.assertTrue(all('@' in package for package in result['packages']))

    def test_local_values_and_package_filters_are_preserved(self):
        result = apply({'localValue': 'preserve-me', 'packages': [
            {'source': 'npm:@ff-labs/pi-fff', 'skills': [], 'extensions': ['extension.ts']},
            'git:git@github.com:alivault/pi-queue-steer',
            'npm:another-local-package@1.0.0',
        ]})
        self.assertEqual(result['localValue'], 'preserve-me')
        self.assertEqual(len(result['packages']), 6)
        filtered = next(p for p in result['packages'] if isinstance(p, dict))
        self.assertEqual(filtered, {'source': 'npm:@ff-labs/pi-fff@0.10.6', 'skills': [], 'extensions': ['extension.ts']})


if __name__ == '__main__':
    unittest.main()
