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
GODOT="/root/tools/godot/godot"

if [ -z "$1" ]; then
    echo "Usage: $0 <test_script.gd> [--width W] [--height H]"
    echo "  test_script.gd  Filename in godotbase/tests/ (e.g. test_my_scene.gd)"
    exit 1
fi

TEST_SCRIPT="tests/$1"
shift

export LD_LIBRARY_PATH="/root/localroot/usr/lib/x86_64-linux-gnu:/root/localroot/usr/lib/x86_64-linux-gnu/dri${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="/root/localroot/usr/lib/x86_64-linux-gnu/dri"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export GODOT_SILENCE_ROOT_WARNING=1
export XKB_CONFIG_ROOT="/root/localroot/usr/share/X11/xkb"
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/lvp_icd.x86_64.json"
export __EGL_VENDOR_LIBRARY_DIRS="/usr/share/glvnd/egl_vendor.d"
export EGL_PLATFORM=surfaceless

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCREENSHOT_DIR="$WORKSPACE_ROOT/screenshot/$TIMESTAMP"
mkdir -p "$SCREENSHOT_DIR"

DISPLAY_NUM=99

pkill -f "Xvfb :$DISPLAY_NUM" 2>/dev/null || true
sleep 1

/root/localroot/usr/bin/Xvfb :$DISPLAY_NUM -screen 0 1280x720x24 -nolisten tcp -xkbdir /root/localroot/usr/share/X11/xkb 2>/dev/null &
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

"$GODOT" --headless --path "$PROJECT_DIR" --import 2>/dev/null

EXIT_CODE=0
"$GODOT" --rendering-driver opengl3 --path "$PROJECT_DIR" -s "$TEST_SCRIPT" \
    -- --screenshot-dir "$SCREENSHOT_DIR" "$@" || EXIT_CODE=$?

echo "============================================"
if [ $EXIT_CODE -eq 0 ]; then
    SHOT_COUNT=$(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l)
    echo " Test PASSED ($SHOT_COUNT screenshots)"
    echo " Screenshots: $SCREENSHOT_DIR"
else
    echo " Test FAILED (exit code: $EXIT_CODE)"
fi
echo "============================================"

exit $EXIT_CODE
