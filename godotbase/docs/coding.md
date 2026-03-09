# GodotBase - Coding Guide

## Requirements

- Godot Engine 4.5+
- Web export templates installed
- Modern web browser

## Accessing Systems

Use `EnvironmentRuntime` to get systems from scene scripts or nodes:

```gdscript
func _ready():
    # Get system from default environment
    var logger = EnvironmentRuntime.get_system("LogSystem")
    var events = EnvironmentRuntime.get_system("EventSystem")
    var web = EnvironmentRuntime.get_system("WebBridgeSystem")
    var resources = EnvironmentRuntime.get_system("ResourceSystem")
```

## Available Systems

| System | Purpose |
|--------|---------|
| `LogSystem` | Logging and debug output |
| `EventSystem` | Event-based communication |
| `WebBridgeSystem` | JavaScript/web communication |
| `ResourceSystem` | Remote resource loading |
| `FontSystem` | Dynamic font loading from PCK |
| `SceneSystem` | Scene loading and management |
| `AudioSystem` | BGM and SFX playback |

## FontSystem Note

Fonts are loaded asynchronously in the loading scene. Current font asset only supports English and Chinese. Check `FontSystem` for how to change fonts.

## EventSystem Note

**Always clean up event listeners in `_exit_tree()`.**

Events registered via `EventSystem.register()` must be unregistered when the node is removed from tree. Otherwise, callbacks will reference freed objects.

## ResourceSystem Usage

**Important:**
- Do not load remote resources before `ResourceController._ready()` is called.
- Remember that after a resource is preloaded, `load_resource` may return the resource before a node is fully set up.


## SceneSystem Usage

**Always use `SceneSystem` for scene operations. Never use native Godot scene methods.**

```gdscript
var scene_system = EnvironmentRuntime.get_system("SceneSystem")

# Load a scene
# You can send custom data to the scene.
scene_system.load_scene("res://scenes/game.tscn")

# Unload a scene
scene_system.unload_scene("res://scenes/menu.tscn")
```

**Forbidden methods:**
- `get_tree().change_scene_to_file()` - forbidden
- `get_tree().change_scene_to_packed()` - forbidden

## AudioSystem Usage

**Use `AudioSystem` for all audio playback. Never create AudioStreamPlayer nodes manually.**

```gdscript
var audio = EnvironmentRuntime.get_system("AudioSystem") as AudioSystem

# Play background music (loops by default)
audio.play_bgm("bgm_main_theme")
audio.play_bgm("bgm_battle", true, 0.8)  # with loop and volume

# Control BGM
audio.stop_bgm()
audio.pause_bgm()
audio.resume_bgm()

# Play sound effects (fire-and-forget)
audio.play_sfx("sfx_click")
audio.play_sfx("sfx_explosion", 0.6)  # with volume

# Volume control (0.0 ~ 1.0)
audio.set_bgm_volume(0.5)
audio.set_sfx_volume(0.8)

# Mute control
audio.set_muted(true)
```

**Custom Player (for sounds needing manual control):**

Use `create_custom_player()` for sounds that need pause/resume, pitch control, or manual stop (e.g., footsteps, engine sounds, ambient loops).

```gdscript
# Create a custom player (loop=true by default)
var footsteps = audio.create_custom_player("walking_ogg", true, 0.3)

# Control the player directly
footsteps.stream_paused = false  # start playing
footsteps.pitch_scale = 1.5      # adjust pitch
footsteps.stream_paused = true   # pause

# Release when done
audio.release_custom_player(footsteps)
```

**Important:**
- Audio resources must be registered in `game_config.json` (same as other resources)
- Preload audio assets in the loading scene via `ResourceSystem` for instant playback
- SFX only plays if the resource is already cached. First call triggers preload for next time
- Web audio unlock is handled automatically on user interaction
- Custom players must be released via `release_custom_player()` when no longer needed

## Scene Flow

`index.tscn` is the bootstrap scene - it loads `loading.tscn` then destroys itself. Do not add game logic to it.

Flow: `index.tscn` → `loading.tscn` → `main.tscn` → other scenes

The `target_scene` is configured in `index.gd`. To change the game scene you want to show, update this parameter.

Rules:
- Add game logic to `main.tscn` or later scenes
- Preload large assets via `ResourceSystem` in the loading scene. See "Loading Scene" section.

## Loading Scene

`loading.tscn` preloads resources (fonts.pck, etc.) and shows a progress bar.

You can add more resources to preload via `ResourceSystem` and update the progress bar. Best practice: preload assets needed immediately by the next scene (e.g., main menu background, font PCK).

`loading.tscn` can be called multiple times. For multi-level games, use it to preload level-specific assets before each level.

## Before Calling Project Functions

**Always check function signatures before calling project-defined functions.**

1. Read `.agent_index/script_symbols.json` to find the function
2. Verify parameter types and order
3. Do not assume API signatures from memory

See `indexing-guide.md` for detailed query workflows.

## Building

```bash
# Build for web
./build.sh

# Clean build artifacts
./tools/clean.sh

# Generate Godot UIDs for .tscn files
./tools/make.sh

# Also generate .gd.uid files (usually unnecessary, auto-generated during build)
./tools/make.sh --scripts
```

## Restrictions

**NEVER modify `public/assets/game_config.json`** - this file is auto-registered by tools.

## Debugging

- First check browser console for JavaScript errors if available.
- Analyze the information and check indexing files. Think about possible causes of the bug.
- Godot headless can help reproduce bugs and verify fixes.

## Best Practices

- Check indexing to plan your task. Avoid building duplicate functions
- Check indexing before you call a function to use it correctly
- Always check `OS.has_feature("web")` before web-specific code
- Do not build unnecessary builds by calling `build.sh` frequently
- Use systems instead of native Godot features (both in system code and game logic). Examples: `LogSystem` instead of `print()`, `SceneSystem` instead of `get_tree().change_scene()`
- Be careful if you really want to change logic in systems. Lots of logic rely on systems and should be stable enough
- When scene code doesn't execute as expected, first verify `target_scene` in `index.gd` points to the correct scene
