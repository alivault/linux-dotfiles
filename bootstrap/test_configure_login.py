import importlib.util
from pathlib import Path
import tomllib
import unittest

spec = importlib.util.spec_from_file_location('login', Path(__file__).with_name('configure-login.py'))
login = importlib.util.module_from_spec(spec)
spec.loader.exec_module(login)


class LoginTests(unittest.TestCase):
    def test_default_requires_password(self):
        config = tomllib.loads(login.login_config('another-user'))
        self.assertNotIn('initial_session', config)
        self.assertEqual(config['default_session']['user'], 'greeter')

    def test_explicit_autologin_and_existing_preservation(self):
        text = login.login_config('another-user', True)
        self.assertEqual(tomllib.loads(text)['initial_session']['user'], 'another-user')
        self.assertEqual(login.existing_policy(text), 'preserve')

    def test_only_stock_agreety_may_be_replaced(self):
        stock = '[terminal]\nvt=1\n[default_session]\ncommand="agreety --cmd /bin/sh"\nuser="greeter"\n'
        self.assertEqual(login.existing_policy(stock), 'stock')
        for custom in [stock.replace('/bin/sh', '/usr/bin/custom'), stock + '[initial_session]\nuser="custom"\ncommand="niri"\n']:
            with self.assertRaises(RuntimeError):
                login.existing_policy(custom)


if __name__ == '__main__':
    unittest.main()
