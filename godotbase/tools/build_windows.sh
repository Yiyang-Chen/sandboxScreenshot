#!/bin/bash
# Build script for GodotBase template (Windows local development)
# This script exports the Godot project to web format
#
# Usage:
#   ./build_windows.sh          - Build using project.godot main_scene -> dist/index.html
#   ./build_windows.sh test     - Build test scene (tests/test_scene/test.tscn) -> dist/test.html
#   ./build_windows.sh <scene>  - Build test scene (tests/test_scene/<scene>.tscn) -> dist/<scene>.html
#
# Note: Web servers automatically serve index.html as the default page.
# Default build uses project.godot's main_scene setting (e.g., loading.tscn).
#
# For sandbox/CI builds, use the root build.sh instead.

# Get the project root directory (parent of tools/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Track temporary test directory (copied from repo root)
_TEMP_TEST_DIR=""

# Parse arguments
# No argument: build using project.godot main_scene setting
# With argument: find <arg>.tscn under tests/ folder (local first, then repo root)
if [ -z "$1" ]; then
    # Use project.godot main_scene (don't override)
    SCENE_NAME=""
    SCENE_PATH=""
    OUTPUT_NAME="index"
else
    SCENE_NAME="$1"
    OUTPUT_NAME="${SCENE_NAME}"
    # Find scene file under local tests/ folder first
    FOUND_FILE=$(find tests -name "${SCENE_NAME}.tscn" -type f 2>/dev/null | head -1)
    # If not found locally, search in repo root tests/
    if [ -z "$FOUND_FILE" ] && [ -d "../tests" ]; then
        REPO_FOUND=$(find ../tests -name "${SCENE_NAME}.tscn" -type f 2>/dev/null | head -1)
        if [ -n "$REPO_FOUND" ]; then
            REPO_TEST_DIR=$(dirname "$REPO_FOUND")
            LOCAL_TEST_DIR="tests/$(basename "$REPO_TEST_DIR")"
            echo "Copying test scene from repo root: $REPO_TEST_DIR -> $LOCAL_TEST_DIR"
            mkdir -p "$LOCAL_TEST_DIR"
            cp -r "$REPO_TEST_DIR"/* "$LOCAL_TEST_DIR"/
            FOUND_FILE=$(find "$LOCAL_TEST_DIR" -name "${SCENE_NAME}.tscn" -type f 2>/dev/null | head -1)
            _TEMP_TEST_DIR="$LOCAL_TEST_DIR"
        fi
    fi
    if [ -n "$FOUND_FILE" ]; then
        SCENE_PATH="res://${FOUND_FILE}"
    else
        echo "Error: ${SCENE_NAME}.tscn not found under tests/ or ../tests/"
        exit 1
    fi
fi

echo "========================================"
echo "GodotBase Web Build"
echo "========================================"
if [ -n "$SCENE_PATH" ]; then
    echo "Scene: ${SCENE_PATH} (override)"
else
    echo "Scene: (using project.godot main_scene)"
fi

# Check if Godot is available
if ! command -v godot &> /dev/null
then
    echo "Error: Godot command not found"
    echo "Please install Godot 4.5+ or add it to your PATH"
    echo "On Windows, you might need to use: godot.exe"
    exit 1
fi

# Generate pck_info.json files before any Godot command
# (FontSystem needs these during initialization, pack_assets.gd will update hash/pck_file later)
if command -v python3 &> /dev/null; then
    python3 tools/generate_pck_info.py
elif command -v python &> /dev/null; then
    python tools/generate_pck_info.py
elif command -v py &> /dev/null; then
    py tools/generate_pck_info.py
else
    echo "Warning: Python not found, skipping pck_info generation"
fi

# Pre-warm: let Godot scan project and build class_name cache
# Using --import to avoid loading autoloads (which may have circular dependencies)
echo "Pre-warming Godot cache..."
godot --headless --import 2>/dev/null || true

# Generate project indices (optional, for agent development)
if [ "${SKIP_INDEXING:-false}" != "true" ]; then
    echo "Generating project indices..."
    if [ -f "tools/agent_index/index.sh" ]; then
        bash tools/agent_index/index.sh incremental || echo "Warning: Indexing failed (non-critical)"
    fi
fi

# Create dist directory if it doesn't exist
if [ ! -d "dist" ]; then
    echo "Creating dist directory..."
    mkdir -p dist
fi

# Clean up temp files (not all PCK - pack_assets.gd handles old version cleanup)
echo "Cleaning up temp files..."
rm -f dist/*_temp.pck 2>/dev/null
rm -f dist/rename_map.txt 2>/dev/null
echo "Clean complete."

# Pack all assets (fonts, loading, etc.) using pack_assets.gd
echo "Packing assets into PCK files..."
godot --headless --script tools/pack_assets.gd -- --type=all

if [ ! -f "dist/pck_index.json" ]; then
    echo "Warning: pck_index.json not generated"
fi

# Rename temp PCK files using rename_map.txt (GDScript rename has issues on Windows)
echo "Renaming PCK files..."
if [ -f "dist/rename_map.txt" ]; then
    while read -r TEMP_FILE FINAL_FILE; do
        if [ -n "$TEMP_FILE" ] && [ -f "dist/$TEMP_FILE" ]; then
            mv -f "dist/$TEMP_FILE" "dist/$FINAL_FILE"
            echo "  Renamed $TEMP_FILE -> $FINAL_FILE"
        fi
    done < dist/rename_map.txt
    rm -f dist/rename_map.txt
fi

# Use Windows export configuration
if [ -f "export_presets_windows.cfg" ]; then
    echo "Using Windows export configuration..."
    cp export_presets_windows.cfg export_presets.cfg
else
    echo "Error: export_presets_windows.cfg not found"
    exit 1
fi

# Backup original project.godot
cp project.godot project.godot.bak

# Modify main_scene only if building a test scene (SCENE_PATH is set)
if [ -n "$SCENE_PATH" ]; then
    echo "Setting main scene to: ${SCENE_PATH}"
    sed -i.tmp "s|run/main_scene=.*|run/main_scene=\"${SCENE_PATH}\"|" project.godot
    rm -f project.godot.tmp
fi

# Export the project
OUTPUT_FILE="dist/${OUTPUT_NAME}.html"
echo "Exporting to ${OUTPUT_FILE}..."
godot --headless --export-release "Web" "${OUTPUT_FILE}"

BUILD_RESULT=$?

# Restore original project.godot
mv project.godot.bak project.godot

# Clean up temporary export_presets.cfg
if [ -f "export_presets.cfg" ]; then
    rm -f export_presets.cfg
    echo "Cleaned up temporary export_presets.cfg"
fi

# Clean up temporary test directory (copied from repo root)
if [ -n "$_TEMP_TEST_DIR" ] && [ -d "$_TEMP_TEST_DIR" ]; then
    echo "Cleaning up temporary test directory: $_TEMP_TEST_DIR"
    rm -rf "$_TEMP_TEST_DIR"
    rmdir tests 2>/dev/null || true
fi

if [ $BUILD_RESULT -eq 0 ]; then
    echo "========================================"
    echo "Build successful!"
    echo "Output: ${OUTPUT_FILE}"
    echo "========================================"
    
    # Copy static assets for HTML loading screen
    echo "Copying static assets..."
    cp -f godot_logo.png dist/
    
    # List generated files
    echo ""
    echo "Generated files:"
    ls -lh dist/${OUTPUT_NAME}.* 2>/dev/null
else
    echo "========================================"
    echo "Build failed!"
    echo "========================================"
    exit 1
fi
