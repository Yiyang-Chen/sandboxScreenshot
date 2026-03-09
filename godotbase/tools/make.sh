#!/bin/bash
# Make/Initialize script for GodotBase template
# This script ensures the project is properly initialized with UIDs

# Usage:
#   bash tools/make.sh           # Generate UIDs for .tscn files only (recommended)
#   bash tools/make.sh --scripts # Also generate .gd.uid files (usually unnecessary)
#
# Note: .gd.uid files are typically not needed as Godot will generate them
# automatically during build/export. Only use --scripts if you need UIDs
# before building (e.g., for version control or manual testing).

# Get the project root directory (parent of tools/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Initializing GodotBase project..."

# ========================================
# Generate ResourceTypes enum
# ========================================
echo "Generating ResourceTypes enum..."
if command -v python3 &> /dev/null; then
    python3 tools/generate_resource_types.py
    if [ $? -eq 0 ]; then
        echo "✓ ResourceTypes generated"
    else
        echo "Warning: Failed to generate ResourceTypes"
    fi
elif command -v python &> /dev/null; then
    python tools/generate_resource_types.py
    if [ $? -eq 0 ]; then
        echo "✓ ResourceTypes generated"
    else
        echo "Warning: Failed to generate ResourceTypes"
    fi
else
    echo "Warning: Python not found, skipping ResourceTypes generation"
fi

# Check if Godot is available
if ! command -v godot &> /dev/null
then
    echo "Error: Godot command not found"
    echo "Please install Godot 4.5+ or add it to your PATH"
    exit 1
fi

# Generate UIDs for scene files (.tscn)
echo "Generating scene UIDs..."

# Check if --scripts flag is provided
if [ "$1" = "--scripts" ]; then
    echo "Note: Also generating .gd.uid files (usually unnecessary)"
    godot --headless --script tools/add_scene_uids.gd -- --scripts 2>&1 | grep -E "(===|✓|✗|Found|->)" || true
else
    godot --headless --script tools/add_scene_uids.gd 2>&1 | grep -E "(===|✓|✗|Found|->)" || true
fi

if [ $? -eq 0 ] || [ $? -eq 141 ]; then
    echo "✓ Project initialized successfully"
    echo "✓ Scene UIDs generated"
    
    # Check if index scene files exist
    if [ -f "scenes/index.tscn" ]; then
        echo "✓ Index scene ready: scenes/index.tscn"
    fi
    
    echo ""
    echo "Project is ready for development!"
else
    echo "Warning: Godot exited with status $?"
    echo "Project may need manual initialization in Godot Editor"
fi

