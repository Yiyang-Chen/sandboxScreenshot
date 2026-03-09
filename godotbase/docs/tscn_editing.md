# TSCN Scene File Editing Guide

## Loading .tscn Files at Runtime

`.tscn` files can be used as **scenes** or **prefabs**:

| Type | Purpose | How to Load |
|------|---------|-------------|
| Scene | Full game screens (menu, level, etc.) | Use `SceneSystem` |
| Prefab | Reusable objects (enemy, bullet, UI component) | Use `preload()` + `instantiate()` |

**Scene loading:**
- Always use `SceneSystem`. See `coding.md` and `.agent_index` for API details.
- Never use native Godot methods like `get_tree().change_scene_to_file()`.

**Prefab instantiation:**
```gdscript
var EnemyPrefab = preload("res://prefabs/enemy.tscn")
var enemy = EnemyPrefab.instantiate()
add_child(enemy)
```

## Scene UID Generation

Scene files (`.tscn`) need a UID in the header for Godot to track them:

```
[gd_scene load_steps=2 format=3 uid="uid://c5qm8k7nxwvlp"]
```

**After creating new `.tscn` files, run:**
```bash
bash tools/make.sh
```

This generates UIDs for `.tscn` files (fast, <1s). Use `--scripts` flag to also generate `.gd.uid` files.

**Never manually write UIDs.** Always let `make.sh` generate them.

## Engine-Level TSCN Knowledge

For Godot engine rules beyond this project's conventions, use `search_knowledge_base` with `category_key="godot_engine"`.
