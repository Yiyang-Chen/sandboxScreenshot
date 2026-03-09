# Project Documentation

This directory contains documentation for AI agents working on this project.

## Documentation by Role

**Always Required:**
- `gdscript-style.md` - GDScript 4.x syntax rules & custom rules for this codebase (critical)

### Designer Agent

**Required:**
- `designer.md` - Project overview and design capabilities

### Developer Agent

**Required:**
- `coding.md` - GDScript development: systems usage, API, best practices
- `tscn_editing.md` - TSCN scene file editing rules
- `indexing-guide.md` - How to query project indices efficiently

**Recommended:**
- `configuration.md` - Project configuration files

## Key Restrictions

1. **Never modify `public/assets/game_config.json`** - managed by tools
2. **Use GDScript only** - no Python syntax
3. **Check indices before reading source files**
4. **Use SceneSystem for all scene operations** - never use native Godot scene methods
