#!/bin/bash
# Clean script for GodotBase template
# This script removes dist artifacts, generated files, and cache files

# Get the project root directory (parent of tools/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Cleaning GodotBase dist artifacts..."

# Remove dist directory
if [ -d "dist" ]; then
    echo "Removing dist directory..."
    rm -rf dist
    echo "dist/ removed"
else
    echo "dist/ directory not found"
fi

# Remove generated pck_infos directory (created by pack_assets.gd)
if [ -d "public/pck_infos" ]; then
    echo "Removing public/pck_infos directory..."
    rm -rf public/pck_infos
    echo "public/pck_infos/ removed"
else
    echo "public/pck_infos/ directory not found"
fi

# Remove .godot cache directory
if [ -d ".godot" ]; then
    echo "Removing .godot cache directory..."
    rm -rf .godot
    echo ".godot/ removed"
else
    echo ".godot/ directory not found"
fi

# Remove .agent_index directory
if [ -d ".agent_index" ]; then
    echo "Removing .agent_index directory..."
    rm -rf .agent_index
    echo ".agent_index/ removed"
else
    echo ".agent_index/ directory not found"
fi

echo ""
echo "Clean complete!"

