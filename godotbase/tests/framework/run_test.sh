#!/bin/bash
# Headless test runner using Xvfb + Godot
# Runs agent-authored test scripts that extend TestRunner.
# Screenshots are saved to screenshot/{timestamp}/ at the workspace root.
#
# Usage (from workspace root):
#   ./godotbase/tests/framework/run_test.sh test_my_scene.gd
#   ./godotbase/tests/framework/run_test.sh test_my_scene.gd --width 1920 --height 1080

set -e

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$FRAMEWORK_DIR/../.." && pwd)"
WORKSPACE_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"

. "$WORKSPACE_ROOT/godot_env.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <test_script.gd> [--width W] [--height H]"
    echo "  test_script.gd  Filename in godotbase/tests/ (e.g. test_my_scene.gd)"
    exit 1
fi

TEST_SCRIPT="tests/$1"
shift

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCREENSHOT_DIR="$WORKSPACE_ROOT/screenshot/$TIMESTAMP"
mkdir -p "$SCREENSHOT_DIR"

DISPLAY_NUM=99

pkill -f "Xvfb :$DISPLAY_NUM" 2>/dev/null || true
sleep 1

"$XVFB_BIN" :$DISPLAY_NUM -screen 0 1280x720x24 -nolisten tcp ${XKB_DIR:+-xkbdir "$XKB_DIR"} 2>/dev/null &
XVFB_PID=$!

cleanup() {
    kill $XVFB_PID 2>/dev/null || true
}
trap cleanup EXIT

sleep 2

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM

echo "============================================"
echo " Test Runner"
echo "============================================"
echo " Script:      $TEST_SCRIPT"
echo " Screenshots: $SCREENSHOT_DIR"
echo " Xvfb:        :$DISPLAY_NUM (PID: $XVFB_PID)"
echo "============================================"

OUTPUT_LOG="$SCREENSHOT_DIR/output.log"

"$GODOT" --headless --path "$PROJECT_DIR" --import 2>/dev/null

"$GODOT" --rendering-driver opengl3 --path "$PROJECT_DIR" -s "$TEST_SCRIPT" \
    -- --screenshot-dir "$SCREENSHOT_DIR" "$@" 2>&1 | tee "$OUTPUT_LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo "============================================"
if [ $EXIT_CODE -eq 0 ]; then
    SHOT_COUNT=$(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l)
    echo " Test PASSED ($SHOT_COUNT screenshots)"
    echo " Screenshots: $SCREENSHOT_DIR"
    echo " Full log:    $OUTPUT_LOG"
else
    echo " Test FAILED (exit code: $EXIT_CODE)"
    echo " Full log:    $OUTPUT_LOG"
fi
echo "============================================"

exit $EXIT_CODE
