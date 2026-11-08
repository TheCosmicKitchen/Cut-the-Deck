#!/usr/bin/env bash
# Checks the Godot engine port against the JS engine: both play the same seeded
# runs and must print identical traces. Usage: GODOT=/path/to/godot tools/parity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
cp data/*.json godot/data/
node tools/trace.mjs > /tmp/ctd-trace-js.txt
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
"$GODOT" --headless --path godot --script res://tests/trace.gd -- /tmp/ctd-trace-gd.txt >/dev/null 2>&1
if diff -q /tmp/ctd-trace-js.txt /tmp/ctd-trace-gd.txt >/dev/null; then
  echo "parity OK: $(wc -l < /tmp/ctd-trace-gd.txt) identical trace lines"
else
  echo "parity FAILED:"; diff /tmp/ctd-trace-js.txt /tmp/ctd-trace-gd.txt | head -20; exit 1
fi
