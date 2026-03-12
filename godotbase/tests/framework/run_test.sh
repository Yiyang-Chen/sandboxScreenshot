#!/bin/bash
# Headless test runner using Xvfb + Godot
# Runs agent-authored test scripts that extend TestRunner.
# Output is saved to tests/test_results/{timestamp}/.
#
# Usage (from project root):
#   bash tests/framework/run_test.sh test_my_scene.gd
#   bash tests/framework/run_test.sh test_my_scene.gd --width 1920 --height 1080

set -e

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$FRAMEWORK_DIR/../.." && pwd)"

# --- Environment setup (Godot + Xvfb + Mesa) ---

GODOT="$(which godot 2>/dev/null || echo '/root/tools/godot/godot')"

if command -v Xvfb &>/dev/null; then
    XVFB_BIN="Xvfb"
elif [ -x "/root/localroot/usr/bin/Xvfb" ]; then
    XVFB_BIN="/root/localroot/usr/bin/Xvfb"
else
    echo "ERROR: Xvfb not found. Run setup.sh first."
    exit 1
fi

if [ -d "/usr/share/X11/xkb" ]; then
    XKB_DIR="/usr/share/X11/xkb"
elif [ -d "/root/localroot/usr/share/X11/xkb" ]; then
    XKB_DIR="/root/localroot/usr/share/X11/xkb"
else
    XKB_DIR=""
fi

if [ -d "/root/localroot/usr/lib/x86_64-linux-gnu" ]; then
    export LD_LIBRARY_PATH="/root/localroot/usr/lib/x86_64-linux-gnu:/root/localroot/usr/lib/x86_64-linux-gnu/dri${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LIBGL_DRIVERS_PATH="/root/localroot/usr/lib/x86_64-linux-gnu/dri"
fi

export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/lvp_icd.x86_64.json"
export __EGL_VENDOR_LIBRARY_DIRS="/usr/share/glvnd/egl_vendor.d"
export EGL_PLATFORM=surfaceless
export GODOT_SILENCE_ROOT_WARNING=1

if [ -n "$XKB_DIR" ]; then
    export XKB_CONFIG_ROOT="$XKB_DIR"
fi

# --- Test execution ---

if [ -z "$1" ]; then
    echo "Usage: $0 <test_script.gd> [--width W] [--height H]"
    echo "  test_script.gd  Filename in tests/ (e.g. test_my_scene.gd)"
    exit 1
fi

TEST_SCRIPT="tests/$1"
shift

TESTS_DIR="$(cd "$FRAMEWORK_DIR/.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCREENSHOT_DIR="$TESTS_DIR/test_results/$TIMESTAMP"
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
