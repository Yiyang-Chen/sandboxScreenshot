#!/bin/bash
# Headless screenshot capture using Xvfb + Godot
# Usage: ./run_capture.sh [--scene scene_path] [--out output.png] [--frames N]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="/root/tools/godot/godot"
PROJECT_DIR="$SCRIPT_DIR/godotbase"

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

DISPLAY_NUM=99

pkill -f "Xvfb :$DISPLAY_NUM" 2>/dev/null || true
sleep 1

/root/localroot/usr/bin/Xvfb :$DISPLAY_NUM -screen 0 1280x720x24 -nolisten tcp -xkbdir /root/localroot/usr/share/X11/xkb 2>/dev/null &
XVFB_PID=$!
sleep 2

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM

echo "Xvfb running on :$DISPLAY_NUM (PID: $XVFB_PID)"
echo "Running Godot capture..."

"$GODOT" --rendering-driver opengl3 --path "$PROJECT_DIR" -s tools/capture_runner.gd -- "$@"
EXIT_CODE=$?

kill $XVFB_PID 2>/dev/null || true
exit $EXIT_CODE
