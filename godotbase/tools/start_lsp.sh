#!/bin/bash
# Start Godot editor in headless mode for IDE integration
# This loads the full project (all resources and scenes) and enables LSP
# Provides complete code navigation, completion, and type checking

# Get the project root directory (parent of tools/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Starting Godot headless editor for project: $PROJECT_ROOT"
echo ""
echo "Starting Godot editor in headless mode (no window will appear)"
echo "This will:"
echo "  - Load all project resources and scenes"
echo "  - Enable Language Server Protocol (LSP)"
echo "  - Provide full IDE integration (completion, navigation, etc.)"
echo ""
echo "Keep this terminal running while editing GDScript files"
echo "Press Ctrl+C to stop the headless editor"
echo ""

# Start Godot editor in headless mode with LSP enabled
# The --headless flag runs without rendering/display
# The --editor flag starts the editor (loads all resources)
# The --lsp-port flag enables LSP server on specified port (using 6008 for Cursor)
# This combination provides full LSP support with all project resources loaded
godot --headless --editor --path "$PROJECT_ROOT" --lsp-port 6008 2>&1

echo ""
echo "Headless editor stopped"
