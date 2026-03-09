#!/bin/bash
# Agent Index Generator (Simplified)
#
# 使用 IndexAutoload 在正常项目上下文中运行，一次调用完成所有索引。
#
# Usage:
#   ./index.sh              # 自动模式（检测变更，增量或跳过）
#   ./index.sh full         # 强制全量索引
#   ./index.sh incremental  # 强制增量索引

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

MODE="${1:-}"

# Check if Godot is available
if ! command -v godot &> /dev/null; then
    echo "[X] Error: Godot command not found"
    echo "    Please install Godot or add it to your PATH"
    exit 1
fi

# Build command args
GODOT_ARGS="--headless -- --index"
if [ -n "$MODE" ]; then
    GODOT_ARGS="$GODOT_ARGS $MODE"
fi

# Run indexing (single Godot call)
echo "Running: godot $GODOT_ARGS"
echo ""

GODOT_OUTPUT=$(godot $GODOT_ARGS 2>&1)
GODOT_EXIT_CODE=$?

# Filter output (remove Godot version and system logs)
echo "$GODOT_OUTPUT" | grep -v "^Godot Engine" | grep -v "^\[.*\]" | grep -v "^$" || true

if [ $GODOT_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "[X] Indexing failed with exit code: $GODOT_EXIT_CODE"
    exit 1
fi

# Verify output files exist
if [ ! -f ".agent_index/script_symbols.json" ]; then
    echo "[X] Failed: script_symbols.json not generated"
    exit 1
fi

echo ""
echo "Done."
