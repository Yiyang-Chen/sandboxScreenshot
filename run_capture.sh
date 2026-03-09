#!/bin/bash
# Headless screenshot capture using Xvfb + Godot
# Usage: ./run_capture.sh [--scene scene_path] [--out output.png] [--frames N]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/godotbase"

. "$SCRIPT_DIR/godot_env.sh"

DISPLAY_NUM=99

pkill -f "Xvfb :$DISPLAY_NUM" 2>/dev/null || true
sleep 1

"$XVFB_BIN" :$DISPLAY_NUM -screen 0 1280x720x24 -nolisten tcp ${XKB_DIR:+-xkbdir "$XKB_DIR"} 2>/dev/null &
XVFB_PID=$!
sleep 2

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM

echo "Xvfb running on :$DISPLAY_NUM (PID: $XVFB_PID)"
echo "Running Godot capture..."

EXIT_CODE=0
"$GODOT" --rendering-driver opengl3 --path "$PROJECT_DIR" -s tools/capture_runner.gd -- "$@" || EXIT_CODE=$?

kill $XVFB_PID 2>/dev/null || true
exit $EXIT_CODE
