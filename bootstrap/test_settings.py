import json
import re
from pathlib import Path
import subprocess
import unittest

MODIFIER = Path(__file__).resolve().parent.parent / 'private_dot_pi/agent/modify_private_settings.json'


def apply(data):
    return json.loads(subprocess.check_output(['sh', str(MODIFIER)], input=json.dumps(data), text=True))


class SettingsTests(unittest.TestCase):
    def test_fresh_defaults_and_idempotence(self):
        result = apply({})
        self.assertEqual(len(result['packages']), 4)
        self.assertEqual(apply(result), result)
        self.assertFalse(result['enableInstallTelemetry'])
        self.assertFalse(any(re.search(r'@[^/@]+$', p) for p in result['packages']), 'not pinned: they get updates')

    def test_agent_shell_prefix(self):
        prefix = apply({})['shellCommandPrefix'].split('\n')
        self.assertEqual(prefix[0], 'set -u', 'an unset variable is an error')
        self.assertEqual(prefix[1], 'export PATH="$HOME/.local/share/agent-guard/bin:$PATH"', 'the rm guard first')

    def test_local_values_and_package_filters_are_preserved(self):
        result = apply({'localValue': 'preserve-me', 'packages': [
            {'source': 'npm:pi-web-access', 'skills': [], 'extensions': ['extension.ts']},
            'git:git@github.com:alivault/pi-queue-steer',
            'npm:another-local-package@1.0.0',
        ]})
        self.assertEqual(result['localValue'], 'preserve-me')
        self.assertEqual(len(result['packages']), 5)
        filtered = next(p for p in result['packages'] if isinstance(p, dict))
        self.assertEqual(filtered, {'source': 'npm:pi-web-access', 'skills': [], 'extensions': ['extension.ts']})

    def test_old_pins_are_dropped(self):
        result = apply({'packages': ['npm:pi-web-access@0.39.0', 'git:https://github.com/alivault/pi-queue-steer@db7989db']})
        self.assertIn('npm:pi-web-access', result['packages'])
        self.assertIn('git:https://github.com/alivault/pi-queue-steer', result['packages'])

    def test_retired_packages_are_removed(self):
        result = apply({'packages': ['npm:@ff-labs/pi-fff@0.10.6', 'npm:pi-mcp-adapter@2.32.1',
                                     'npm:@howaboua/pi-codex-conversion@3.0.29',
                                     'npm:@injaneity/pi-computer-use@0.5.1', 'npm:kept-local@1.0.0']})
        sources = [p if isinstance(p, str) else p['source'] for p in result['packages']]
        self.assertFalse(any(x in s for s in sources for x in ('pi-fff', 'mcp-adapter', 'codex-conversion', 'computer-use')))
        self.assertIn('npm:kept-local@1.0.0', sources)

    def test_the_macs_choices(self):
        result = apply({'terminal': {'other': 1}})
        self.assertEqual((result['defaultProvider'], result['defaultModel'], result['defaultThinkingLevel']),
                         ('anthropic', 'claude-opus-5-5', 'medium'))
        self.assertEqual(result['terminal'], {'other': 1, 'showTerminalProgress': False}, 'merged, not replaced')
        self.assertEqual(result['markdown'], {'mermaid': 'streaming'})

if __name__ == '__main__':
    unittest.main()
