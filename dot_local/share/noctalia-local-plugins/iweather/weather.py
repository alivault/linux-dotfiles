"""Bounded Open-Meteo client for iWeather; no dependencies or API keys."""
import argparse
import datetime as dt
import json
import math
import os
from pathlib import Path
import tempfile
import time
import urllib.parse
import urllib.request

TTL = 900


def request(host, path, params):
    url = 'https://' + host + path + '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'iWeather-Noctalia/1.0', 'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=15) as response:
        data = response.read(1_048_577)
    if len(data) > 1_048_576:
        raise ValueError('Response too large')
    return json.loads(data)


def read(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def location(value):
    lat, lon = float(value['latitude']), float(value['longitude'])
    if not math.isfinite(lat) or not math.isfinite(lon) or not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError('Invalid coordinates')
    name = str(value.get('name') or 'Selected location')[:100]
    return {'name': name, 'latitude': lat, 'longitude': lon,
            'label': str(value.get('label') or name)[:160]}


def condition(code, day=True):
    if code == 0:
        return ('Clear', 'sun' if day else 'moon-stars')
    if code in (1, 2):
        return ('Partly cloudy', 'cloud-sun' if day else 'cloud-moon')
    if code == 3:
        return ('Overcast', 'cloud')
    if code in (45, 48):
        return ('Fog', 'mist')
    if code in (51, 53, 55, 56, 57):
        return ('Drizzle', 'cloud-rain')
    if code in (61, 63, 65, 66, 67, 80, 81, 82):
        return ('Rain', 'cloud-rain')
    if code in (71, 73, 75, 77, 85, 86):
        return ('Snow', 'cloud-snow')
    if code in (95, 96, 99):
        return ('Thunderstorms', 'cloud-storm')
    return ('Unknown conditions', 'cloud')


def normalize(raw, place, units):
    def temp(value):
        value = float(value)
        if not math.isfinite(value):
            raise ValueError('Invalid temperature')
        return round(value * 9 / 5 + 32 if units == 'F' else value)
    current, hourly, daily = raw['current'], raw['hourly'], raw['daily']
    description, glyph = condition(current['weather_code'], current.get('is_day', 1) == 1)
    now_hour = current['time'][:13] + ':00'
    hours = []
    for i, stamp in enumerate(hourly['time']):
        if stamp < now_hour:
            continue
        _, icon = condition(hourly['weather_code'][i], hourly['is_day'][i] == 1)
        hours.append({'label': dt.datetime.fromisoformat(stamp).strftime('%I %p').lstrip('0'),
                      'temp': temp(hourly['temperature_2m'][i]), 'glyph': icon})
        if len(hours) == 6:
            break
    days = []
    for i, stamp in enumerate(daily['time'][:5]):
        _, icon = condition(daily['weather_code'][i])
        days.append({'label': dt.date.fromisoformat(stamp).strftime('%a').upper(), 'glyph': icon,
                     'low': temp(daily['temperature_2m_min'][i]), 'high': temp(daily['temperature_2m_max'][i])})
    if not days or not hours:
        raise ValueError('Incomplete forecast')
    return {'name': place['name'], 'units': units, 'temp': temp(current['temperature_2m']),
            'description': description, 'glyph': glyph, 'high': days[0]['high'], 'low': days[0]['low'],
            'hours': hours, 'days': days, 'stale': False}


def execute(directory, action, payload=''):
    settings_path = directory / 'settings.json'
    settings = read(settings_path)
    units = settings.get('units', 'C')
    if action == 'search':
        query = payload.strip()[:80]
        if len(query) < 2:
            return {'results': []}
        raw = request('geocoding-api.open-meteo.com', '/v1/search',
                      {'name': query, 'count': 5, 'language': 'en', 'format': 'json'})
        results = []
        for item in raw.get('results', [])[:5]:
            label = ', '.join(str(item[k]) for k in ('name', 'admin1', 'country') if item.get(k))
            results.append(location(dict(item, label=label)))
        return {'results': results}
    if action == 'select':
        settings['location'] = location(json.loads(payload))
        write(settings_path, settings)
    if action == 'units':
        units = 'F' if units == 'C' else 'C'
        settings['units'] = units
        write(settings_path, settings)
    place = settings.get('location')
    if not place:
        # Reuse the location already resolved by Noctalia; no extra IP geolocation request.
        cache_home = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache'))
        cached_location = read(cache_home / 'noctalia/location.json')
        if not cached_location:
            return {'needs_location': True, 'units': units}
        place = cached_location
    place = location(place)
    key = [place['latitude'], place['longitude']]
    cache_path = directory / 'forecast.json'
    cache = read(cache_path)
    matches = cache.get('key') == key
    raw = cache.get('raw') if matches else None
    stale = False
    if action == 'refresh' or not raw or time.time() - cache.get('at', 0) >= TTL:
        try:
            fetched = request('api.open-meteo.com', '/v1/forecast', {
                'latitude': key[0], 'longitude': key[1], 'timezone': 'auto', 'forecast_days': 5,
                'current': 'temperature_2m,weather_code,is_day',
                'hourly': 'temperature_2m,weather_code,is_day',
                'daily': 'weather_code,temperature_2m_max,temperature_2m_min'})
            normalize(fetched, place, units)  # Validate before replacing a good cache.
            raw = fetched
            cache = {'key': key, 'at': time.time(), 'raw': raw}
            write(cache_path, cache)
        except (OSError, ValueError, KeyError, TypeError, IndexError):
            if not raw:
                return {'error': 'Weather unavailable. Try refresh shortly.', 'units': units}
            stale = True
    result = normalize(raw, place, units)
    result.update(stale=stale, fetched_at=cache.get('at', 0))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('action', choices=['snapshot', 'refresh', 'search', 'select', 'units'])
    parser.add_argument('payload', nargs='?', default='')
    args = parser.parse_args()
    try:
        result = execute(args.data_dir, args.action, args.payload)
    except (OSError, ValueError, KeyError, TypeError, IndexError):
        result = {'error': 'Unable to load weather data. Please try again.'}
    print(json.dumps(result, separators=(',', ':'), allow_nan=False))
