# Agent Index Tools

Tools for generating structured JSON indices of Godot project structure.

## Overview

This toolset generates four index files in `.agent_index/`:
- `repo_map.json` - Project metadata and entry points
- `scene_map.json` - Scene structure and node-script relationships
- `script_symbols.json` - Script symbols (functions, signals, exports)
- `index_state.json` - Index metadata and timestamps

## Requirements

- Godot 4.5+ (in PATH)
- Bash shell (Git Bash or WSL on Windows)

## Usage

```bash
# Auto mode: detect changes, run incremental or skip if no changes
./tools/agent_index/index.sh

# Force full rebuild
./tools/agent_index/index.sh full

# Force incremental (process changed files only)
./tools/agent_index/index.sh incremental
```

### Windows (PowerShell)

```powershell
# Run via bash (Git Bash or WSL)
bash tools/agent_index/index.sh full
```

## How It Works

The indexing is performed by `IndexAutoload`, which is registered as an autoload in `project.godot`. When run with `--index` argument, it:

1. Detects changed files using mtime comparison
2. Generates all index files in a single Godot call
3. Exits automatically after completion

In normal game mode (without `--index`), the autoload immediately frees itself.

## Output Format

See `docs/indexing-guide.md` for detailed schema documentation.

## Troubleshooting

**Godot not found:**
- Add Godot to PATH or use full path to executable

**Permission denied on index.sh:**
- Make executable: `chmod +x tools/agent_index/index.sh`

**Script extraction failed:**
- Check for syntax errors in your GDScript files
- Run `godot --headless -- --index full` directly to see detailed errors
