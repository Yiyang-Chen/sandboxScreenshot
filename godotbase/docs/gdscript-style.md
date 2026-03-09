# GDScript 4.x Project Requirements

## Critical Rules

1. **This project MUST be implemented entirely in GDScript**
2. **This project MUST use Godot 4.x GDScript syntax**
3. **GDScript is NOT Python - do not confuse them**
4. **All classes MUST explicitly declare inheritance** (e.g., `extends RefCounted`, `extends Node`, `extends Resource`) - no implicit inheritance
5. **No emojis allowed** - Do not use any emoji characters in code, strings, comments, or UI text

## Best Practice: Use SceneSystem

Always use `SceneSystem` for scene operations (see `coding.md`). Never use native Godot methods like `get_tree().change_scene_to_file()`.

## Engine-Level GDScript Knowledge

For Godot engine rules beyond this project's conventions, use `search_knowledge_base` with `category_key="godot_engine"`.
