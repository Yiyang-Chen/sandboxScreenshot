#!/bin/bash
# Shared environment setup for headless Godot rendering.
# Source this file from run scripts: . "$SCRIPT_DIR/godot_env.sh"
#
# After sourcing, these variables are available:
#   GODOT       - path to Godot binary
#   XVFB_BIN   - path to Xvfb binary
#   XKB_DIR    - path to xkb data directory

GODOT="/root/tools/godot/godot"

# Find Xvfb (system PATH first, then localroot fallback)
if command -v Xvfb &>/dev/null; then
    XVFB_BIN="Xvfb"
elif [ -x "/root/localroot/usr/bin/Xvfb" ]; then
    XVFB_BIN="/root/localroot/usr/bin/Xvfb"
else
    echo "ERROR: Xvfb not found. Run ./setup.sh first."
    exit 1
fi

# Find xkb data
if [ -d "/usr/share/X11/xkb" ]; then
    XKB_DIR="/usr/share/X11/xkb"
elif [ -d "/root/localroot/usr/share/X11/xkb" ]; then
    XKB_DIR="/root/localroot/usr/share/X11/xkb"
else
    XKB_DIR=""
fi

# Localroot library paths (only if the directory exists)
if [ -d "/root/localroot/usr/lib/x86_64-linux-gnu" ]; then
    export LD_LIBRARY_PATH="/root/localroot/usr/lib/x86_64-linux-gnu:/root/localroot/usr/lib/x86_64-linux-gnu/dri${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LIBGL_DRIVERS_PATH="/root/localroot/usr/lib/x86_64-linux-gnu/dri"
fi

# Mesa software rendering
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
