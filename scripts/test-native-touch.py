#!/usr/bin/env python3
"""Run iOS interaction tests using real Simulator touches, without screenshots."""
import re
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='coolvibes-touch-') as temporary:
    driver = str(Path(temporary) / 'touch')
    subprocess.run(['swiftc', str(root / 'scripts/simulator-touch.swift'), '-o', driver], check=True)
    subprocess.run(['osascript', '-e', 'tell application "Simulator" to activate'], check=True)
    command = ['flutter', 'test', *sys.argv[1:], '--dart-define=NATIVE_HOST_TOUCH=true', '--no-pub', '--reporter', 'expanded']
    process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            match = re.search(r'COOLVIBES_TOUCH ([0-9. -]+)', line)
            if not match:
                continue
            points = list(map(float, match.group(1).split()))
            window_name = os.environ.get('COOLVIBES_SIMULATOR_WINDOW', '')
            script = '''on run argv
              tell application "System Events" to tell process "Simulator"
                set frontmost to true
                if item 1 of argv is "" then
                  set targetWindow to window 1
                else
                  set targetWindow to first window whose name contains (item 1 of argv)
                end if
                perform action "AXRaise" of targetWindow
                return {position, size} of first group of targetWindow
              end tell
            end run'''
            geometry = None
            for attempt in range(3):
                result = subprocess.run(['osascript', '-e', script, window_name], text=True, capture_output=True)
                if result.returncode == 0:
                    geometry = result.stdout
                    break
                # Flutter may launch the runner while Simulator has no window.
                # Reopen only the device explicitly selected for this test run.
                device_index = sys.argv.index('-d') + 1
                subprocess.run(['open', '-a', 'Simulator', '--args', '-CurrentDeviceUDID', sys.argv[device_index]], check=True)
                time.sleep(0.3)
            if geometry is None:
                raise RuntimeError('Simulator test window is unavailable: ' + result.stderr)
            x, y, width, height = map(float, re.findall(r'[-\d.]+', geometry))
            values = [x + points[0] * width, y + points[1] * height, width, height]
            if len(points) == 4:
                values += [x + points[2] * width, y + points[3] * height]
            subprocess.run([driver, *map(str, values)], check=True)
            acknowledgement = re.search(r'ACK:(\d+)', line)
            if acknowledgement:
                request = urllib.request.Request(
                    f'http://127.0.0.1:{acknowledgement.group(1)}/', method='POST')
                with urllib.request.urlopen(request, timeout=10):
                    pass
        sys.exit(process.wait())
    finally:
        if process.poll() is None:
            process.terminate()
