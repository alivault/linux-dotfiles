# Third-party notices

## Omarchy

The retained tmux bindings, screensaver text/behavior and some desktop/editor
configuration are adapted from [Omarchy](https://github.com/basecamp/omarchy).
They are independent copies, not runtime integrations. These portions remain
under the following MIT license; retaining this legal attribution is intentional.

Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## iWeather

The native Noctalia widget's design is adapted from
[alivault/iweather](https://github.com/alivault/iweather), revision
`959c6d463cd48d73b4ca2648759b836d2bf8ec6e`, originally derived from Omarchy's
weather widget. Its MIT notices are retained in
`dot_local/share/noctalia-local-plugins/iweather/LICENSE`. No Omarchy runtime
is used. The gradient PNG is original generated artwork; its reproducible
generator is `bootstrap/generate-iweather-gradient.py`.

Weather data: Open-Meteo; location search: Open-Meteo/GeoNames. Attribution is
shown in the panel. Runtime data and selected locations are not redistributed.

## LazyVim

The Neovim configuration includes material adapted from
[LazyVim/starter](https://github.com/LazyVim/starter) and LazyVim contributors,
under Apache-2.0. Its full license is retained at
[`dot_config/nvim/LICENSE`](dot_config/nvim/LICENSE). Local modifications preserve
the existing clipboard, keymaps, Neo-tree and transparency behavior, use Tokyo
Night, and bootstrap the plugin manager from the checked-in lockfile.

## Desktop assets

`dot_local/share/desktop-assets/wallpaper.png` is original generated artwork,
covered by this repository's MIT license. Recreate it with
`python3 bootstrap/generate-wallpaper.py`. The pre-existing personal JPEG is not
redistributed. Arch naming/logo references do not imply project endorsement.

## Downloaded software

Pinned third-party binaries, the Whisper model, editor plugins, Pi packages,
greeter and QEMU sources are downloaded separately, not relicensed by this
repository. Their upstream licenses apply. The local package recipes retain
their upstream license files in the built packages. Review URLs and hashes in
`bootstrap/` before executing installers or third-party extension code.
