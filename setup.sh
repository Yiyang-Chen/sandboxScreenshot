#!/bin/bash
# One-step environment setup for headless Godot screenshot capture.
# Installs system dependencies, downloads Godot, and configures export templates.
#
# Usage: ./setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_VERSION="4.5.1"
GODOT_DIR="/root/tools/godot"
GODOT_BIN="$GODOT_DIR/godot"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

echo "============================================"
echo " Godot Headless Screenshot - Environment Setup"
echo "============================================"

# --------------------------------------------------
# 1. System dependencies
# --------------------------------------------------
echo ""
echo "[1/4] Installing system dependencies..."

PACKAGES=(
    # Xvfb / X11
    xvfb
    x11-xkb-utils
    xkb-data
    # Mesa / OpenGL (software rendering via llvmpipe)
    libgl1-mesa-dri
    libegl-mesa0
    libegl1
    libglx-mesa0
    libgbm1
    mesa-vulkan-drivers
    # DRM
    libdrm2
    libdrm-intel1
    libdrm-amdgpu1
    libdrm-nouveau2
    libdrm-radeon1
    libpciaccess0
    # X11 client libraries
    libxcursor1
    libxi6
    libxrandr2
    libxinerama1
    libx11-xcb1
    # XCB extensions
    libxcb-cursor0
    libxcb-icccm4
    libxcb-keysyms1
    # Other
    libxkbcommon0
    fontconfig
)

if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq "${PACKAGES[@]}" 2>&1 | tail -3
    echo "  System packages installed via apt-get"
else
    echo "  WARNING: apt-get not available. Assuming dependencies are pre-installed."
    echo "  If Godot fails to run, install these packages manually:"
    printf '    %s\n' "${PACKAGES[@]}"
fi

# --------------------------------------------------
# 2. Godot Engine
# --------------------------------------------------
echo ""
echo "[2/4] Setting up Godot ${GODOT_VERSION}..."

if [ -x "$GODOT_BIN" ]; then
    echo "  Godot already installed at $GODOT_BIN"
else
    mkdir -p "$GODOT_DIR"
    GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
    echo "  Downloading from $GODOT_URL ..."
    curl -fSL -o /tmp/godot.zip "$GODOT_URL"
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/godot.zip').extractall('$GODOT_DIR')"
    mv "$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$GODOT_BIN"
    chmod +x "$GODOT_BIN"
    rm -f /tmp/godot.zip
    echo "  Godot installed at $GODOT_BIN"
fi

# --------------------------------------------------
# 3. Web export template
# --------------------------------------------------
echo ""
echo "[3/4] Configuring web export template..."

TEMPLATE_SRC="$SCRIPT_DIR/templates/web_nothreads_release_no_wasm.zip"
if [ -f "$TEMPLATE_SRC" ]; then
    mkdir -p "$TEMPLATE_DIR"
    cp "$TEMPLATE_SRC" "$TEMPLATE_DIR/"
    echo "  Template copied to $TEMPLATE_DIR/"
else
    echo "  WARNING: Template not found at $TEMPLATE_SRC"
    echo "  Web export will not work until the template is provided."
fi

# --------------------------------------------------
# 4. Verify
# --------------------------------------------------
echo ""
echo "[4/4] Verifying setup..."

ERRORS=0

if [ -x "$GODOT_BIN" ]; then
    GODOT_VER=$("$GODOT_BIN" --version 2>/dev/null || echo "unknown")
    echo "  Godot:  OK ($GODOT_VER)"
else
    echo "  Godot:  MISSING"
    ERRORS=$((ERRORS + 1))
fi

if command -v Xvfb &>/dev/null; then
    echo "  Xvfb:   OK ($(command -v Xvfb))"
elif [ -x "/root/localroot/usr/bin/Xvfb" ]; then
    echo "  Xvfb:   OK (/root/localroot/usr/bin/Xvfb)"
else
    echo "  Xvfb:   MISSING"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$TEMPLATE_DIR/web_nothreads_release_no_wasm.zip" ]; then
    echo "  Export: OK"
else
    echo "  Export: MISSING (web export will not work)"
fi

echo ""
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo " Setup complete! Ready to use."
    echo ""
    echo " Run a test:"
    echo "   ./godotbase/tests/framework/run_test.sh framework/example_test.gd"
else
    echo " Setup completed with $ERRORS error(s). See above."
fi
echo "============================================"
