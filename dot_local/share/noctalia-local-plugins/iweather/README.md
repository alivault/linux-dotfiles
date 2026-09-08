# Native Noctalia iWeather

Native Luau panel/bar/service with a Python-standard-library data helper. Visual
design adapted from https://github.com/alivault/iweather at commit
`959c6d463cd48d73b4ca2648759b836d2bf8ec6e` (MIT; notices retained in LICENSE).
That original design derives from Omarchy's weather widget. No Omarchy or QML
runtime code, configuration, commands or packages are required here.

- Left click opens the forecast; middle click refreshes; right click switches °C/°F.
- Click the city name to reveal city/ZIP search, unit switching and refresh.
  Press Enter to search, then select a result.
- Six hourly slots and five daily ranges reproduce the original layout. Main
  colors follow Noctalia; temperature bars retain iWeather's blue/pink gradient.
- The compact panel uses a 12pt (16 logical px) sans-serif base, 40px daily rows,
  aligned day/icon/low/range/high columns and a 440×480 logical-pixel surface.
  Hour labels use compact 24-hour notation. Noctalia handles HiDPI scaling.
  The normal forecast fits without scrolling; expanded search can scroll.
- First use reads the already-resolved location from Noctalia's local cache.
  Otherwise the panel asks for a location. No additional IP geolocation service
  is contacted. A selected location and units persist only in pluginDataDir().
- Coordinates go to api.open-meteo.com; search text goes to
  geocoding-api.open-meteo.com. No credentials, keys or telemetry. Weather data
  is attributed to Open-Meteo under https://creativecommons.org/licenses/by/4.0/.
- Fifteen-minute cache; network timeouts, response limits and cached/offline
  fallback. HTTP/JSON normalization run outside Luau; UI receives only a compact
  forecast. Noctalia's execution budgets remain unchanged.
- This design-based version uses Open-Meteo globally. The original's U.S. NWS
  observations and alerts are not ported; this is not an emergency-alert system.

The source is local/chezmoi-managed, so community updates cannot overwrite it.
`gradient.png` is original generated artwork (MIT), reproducible with
`python3 bootstrap/generate-iweather-gradient.py` from the dotfiles repository.
