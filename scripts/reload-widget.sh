#!/bin/bash
# Reload only this installed app's widget process after replacing the bundle.
# Does not remove widgets, clear caches, or restart other desktop widgets.
set -euo pipefail
check_only=0
if [[ "${1:-}" == '--check' ]]; then check_only=1; shift; fi
app="${1:-/Applications/WorkBuddy Credits.app}"
if [[ $# -gt 1 ]]; then echo 'Usage: bash scripts/reload-widget.sh [--check] [installed-app-path]' >&2; exit 2; fi
extension="$app/Contents/PlugIns/WorkBuddyCreditsWidget.appex"
if [[ ! -f "$extension/Contents/Info.plist" ]]; then echo 'Installed WorkBuddy widget not found.' >&2; exit 1; fi
codesign --verify --deep --strict "$app"
if [[ "$check_only" == 0 ]]; then /usr/bin/pluginkit -a "$extension"; fi
python3 - "$extension" "$check_only" <<'PY'
import os
import pathlib
import plistlib
import signal
import subprocess
import sys

extension = pathlib.Path(sys.argv[1]).resolve()
info = plistlib.loads((extension / 'Contents/Info.plist').read_bytes())
if info.get('CFBundleExecutable') != 'WorkBuddyCreditsWidget':
    raise SystemExit('Unexpected executable; refusing to stop any process.')
expected = str(extension / 'Contents/MacOS/WorkBuddyCreditsWidget')
rows = subprocess.check_output(['/bin/ps', '-axo', 'pid=,comm='], text=True).splitlines()
pids = []
for row in rows:
    parts = row.strip().split(None, 1)
    if len(parts) == 2 and parts[1] == expected:
        pids.append(int(parts[0]))
if sys.argv[2] == '1':
    print(f"Installed widget: {info['CFBundleIdentifier']} {info['CFBundleShortVersionString']}")
    print(f'Matching widget processes: {len(pids)}')
    for pid in pids:
        subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'pid=,lstart='], check=True)
else:
    stopped = 0
    for pid in pids:
        # Recheck immediately before signalling, in case a PID has been reused.
        current = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'comm='], capture_output=True, text=True)
        if current.returncode == 0 and current.stdout.strip() == expected:
            try:
                os.kill(pid, signal.SIGTERM)
                stopped += 1
            except ProcessLookupError:
                pass
    print(f'Registered the installed extension and stopped {stopped} old widget process(es).')
    print('macOS will reload it. Use Refresh in the main app, then check the desktop card.')
PY
