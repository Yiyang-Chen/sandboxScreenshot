#!/bin/bash
# Sandbox/CI Build script for GodotBase template
# This script uses sandbox configuration with /app/ templates

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "Building GodotBase for Web (Sandbox)..."

# Use sandbox export configuration
if [ -f "export_presets_sandbox.cfg" ]; then
    echo "Using sandbox export configuration..."
    cp export_presets_sandbox.cfg export_presets.cfg
else
    echo "Error: export_presets_sandbox.cfg not found"
    exit 1
fi

# Check if Godot is available
if ! command -v godot &> /dev/null
then
    echo "Error: Godot command not found"
    echo "Please install Godot 4.5+ or add it to your PATH"
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

# Export the project
echo "Exporting to dist/index.html..."
godot --headless --export-release "Web" dist/index.html

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Output: dist/index.html"
    
    # Copy static assets for HTML loading screen
    echo "Copying static assets..."
    cp -f godot_logo.png dist/
    
    # Clean up temporary export_presets.cfg
    if [ -f "export_presets.cfg" ]; then
        rm -f export_presets.cfg
        echo "Cleaned up temporary export_presets.cfg"
    fi
else
    echo "Build failed!"
    # Clean up temporary export_presets.cfg even on failure
    if [ -f "export_presets.cfg" ]; then
        rm -f export_presets.cfg
    fi
    exit 1
fi
