import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('iweather', ROOT / 'dot_local/share/noctalia-local-plugins/iweather/weather.py')
weather = importlib.util.module_from_spec(spec)
spec.loader.exec_module(weather)
PLACE = {'name': 'Test City', 'latitude': 0, 'longitude': 0}


def forecast():
    return {
        'current': {'time': '2026-01-01T12:30', 'temperature_2m': 10, 'weather_code': 0, 'is_day': 0},
        'hourly': {'time': [f'2026-01-01T{h:02d}:00' for h in range(24)],
                   'temperature_2m': [10] * 24, 'weather_code': [2] * 24, 'is_day': [1] * 24},
        'daily': {'time': [f'2026-01-0{d}' for d in range(1, 6)], 'weather_code': [3] * 5,
                  'temperature_2m_min': [0] * 5, 'temperature_2m_max': [20] * 5},
    }


class WeatherTests(unittest.TestCase):
    def test_bounded_forecast_and_units(self):
        data = weather.normalize(forecast(), PLACE, 'C')
        self.assertEqual((len(data['hours']), len(data['days'])), (6, 5))
        self.assertEqual(data['hours'][0]['label'], '12 PM')
        self.assertEqual(data['glyph'], 'moon-stars')
        self.assertEqual(weather.normalize(forecast(), PLACE, 'F')['temp'], 50)

    def test_invalid_coordinates_and_missing_data(self):
        for lat in [91, float('nan'), float('inf')]:
            with self.assertRaises(ValueError):
                weather.location(dict(PLACE, latitude=lat))
        data = forecast()
        data['daily']['time'] = []
        with self.assertRaises(ValueError):
            weather.normalize(data, PLACE, 'C')

    def test_cache_toggle_and_offline_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            weather.write(root / 'settings.json', {'location': PLACE})
            with patch.object(weather, 'request', return_value=forecast()) as fetch:
                self.assertFalse(weather.execute(root, 'snapshot')['stale'])
                self.assertEqual(weather.execute(root, 'units')['temp'], 50)
                self.assertEqual(fetch.call_count, 1)
            with patch.object(weather, 'request', side_effect=OSError('offline')):
                self.assertTrue(weather.execute(root, 'refresh')['stale'])
                other = dict(PLACE, latitude=1, name='Other City')
                self.assertIn('error', weather.execute(root, 'select', json.dumps(other)))

    def test_search_is_bounded(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(weather, 'request', return_value={'results': [PLACE] * 20}) as fetch:
                self.assertEqual(len(weather.execute(Path(tmp), 'search', 'x' * 200)['results']), 5)
                self.assertEqual(len(fetch.call_args.args[2]['name']), 80)


if __name__ == '__main__':
    unittest.main()
