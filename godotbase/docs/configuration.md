# GodotBase Configuration

## Key Configuration Files

### `project.godot`
Main Godot project settings. Edit via Project → Project Settings in Godot editor.

### `export_presets.cfg`
Web export configuration. Edit via Project → Export in Godot editor.

### `export_template.html`
Custom HTML template with Godot placeholders:
- `$GODOT_URL` - Engine JS path
- `$GODOT_CONFIG` - Configuration object
- `$GODOT_THREADS_ENABLED` - Thread support
- `$GODOT_PROJECT_NAME` - Project name
- `$GODOT_HEAD_INCLUDE` - Head includes
- `$GODOT_SPLASH*` - Splash screen settings

### `public/assets/game_config.json`
Game-specific configuration for custom data.

### `public/assets/*/manifest.json`
Asset packing configuration per directory. Each directory under `public/assets/` with a `manifest.json` is auto-discovered by `pack_assets.gd` and packed into a separate PCK file.

Fields:
- `extensions` - File extensions to scan and pack
- `internal_prefix` - Internal path prefix inside the PCK (e.g. `res://loading/`)
- `pack_imported` (optional, default `true`) - When `true`, packs original file + `.import` + compiled resource (`.ctex`/`.fontdata`). When `false`, packs only the original file (for assets loaded via `FileAccess` instead of `load()`)

### `project_env.json`
Agent integration configuration.
