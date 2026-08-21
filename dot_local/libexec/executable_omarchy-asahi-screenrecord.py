#!/usr/bin/env python3
"""Translate Omarchy's gpu-screen-recorder invocation to wf-recorder on Asahi."""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys


def fail(message: str, status: int = 1) -> None:
    print(f"Asahi screen recorder: {message}", file=sys.stderr)
    raise SystemExit(status)


def command_output(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        fail(f"command failed: {' '.join(args)}")


target = ""
resolution = ""
framerate = "60"
audio_devices = ""
output_file = ""

args = sys.argv[1:]
index = 0
value_options = {"-w", "-s", "-f", "-a", "-o"}
ignored_value_options = {"-k", "-fm", "-fallback-cpu-encoding", "-ac"}

while index < len(args):
    option = args[index]
    if option in value_options | ignored_value_options:
        if index + 1 >= len(args):
            fail(f"option requires a value: {option}", 2)
        value = args[index + 1]
        if option == "-w":
            target = value
        elif option == "-s":
            resolution = value
        elif option == "-f":
            framerate = value
        elif option == "-a":
            audio_devices = value
        elif option == "-o":
            output_file = value
        index += 2
    else:
        fail(f"unsupported gpu-screen-recorder option: {option}", 2)

if not target or not output_file:
    fail("capture target or output file is missing", 2)
if target == "portal":
    fail(
        "the portal backend is unsupported; unset OMARCHY_SCREENRECORD_USE_PORTAL",
        2,
    )

wf_args = ["wf-recorder", "--no-dmabuf", "-c", "libx264", "-r", framerate, "-y"]

region = re.fullmatch(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", target)
if region:
    width, height, x, y = region.groups()
    wf_args += ["-g", f"{x},{y} {width}x{height}"]
else:
    wf_args += ["-o", target]

if resolution and resolution != "0x0":
    size = re.fullmatch(r"(\d+)x(\d+)", resolution)
    if not size:
        fail(f"invalid resolution: {resolution}", 2)
    wf_args += ["-F", f"scale={size.group(1)}:{size.group(2)}"]

loaded_modules: list[str] = []


def load_module(name: str, *module_args: str) -> str:
    try:
        module_id = subprocess.check_output(
            ["pactl", "load-module", name, *module_args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        fail("could not create the desktop/microphone audio mix")
    loaded_modules.append(module_id)
    return module_id


def unload_audio_modules() -> None:
    for module_id in reversed(loaded_modules):
        subprocess.run(
            ["pactl", "unload-module", module_id],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


if audio_devices:
    desktop_source = ""
    microphone_source = ""
    if "default_output" in audio_devices:
        desktop_source = f"{command_output('pactl', 'get-default-sink')}.monitor"
    if "default_input" in audio_devices:
        microphone_source = command_output("pactl", "get-default-source")

    if desktop_source and microphone_source:
        mix_sink = f"omarchy_screenrecord_mix_{os.getpid()}"
        load_module(
            "module-null-sink",
            f"sink_name={mix_sink}",
            "sink_properties=device.description=OmarchyScreenrecordMix",
        )
        load_module(
            "module-loopback",
            f"source={desktop_source}",
            f"sink={mix_sink}",
            "latency_msec=20",
        )
        load_module(
            "module-loopback",
            f"source={microphone_source}",
            f"sink={mix_sink}",
            "latency_msec=20",
        )
        audio_source = f"{mix_sink}.monitor"
    elif desktop_source:
        audio_source = desktop_source
    elif microphone_source:
        audio_source = microphone_source
    else:
        fail("requested audio source is unavailable")

    wf_args += [f"--audio={audio_source}", "-C", "aac"]

wf_args += ["-f", output_file]
child: subprocess.Popen[bytes] | None = None


def forward_stop(_signum: int, _frame: object) -> None:
    if child is not None and child.poll() is None:
        child.send_signal(signal.SIGINT)


# Omarchy launches this process in the background and stops it with SIGINT.
# Registering the handler explicitly also repairs an inherited ignored SIGINT.
signal.signal(signal.SIGINT, forward_stop)
signal.signal(signal.SIGTERM, forward_stop)

try:
    child = subprocess.Popen(wf_args)
    status = child.wait()
finally:
    unload_audio_modules()

raise SystemExit(status)
