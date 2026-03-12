# GDScript 4.x Project Requirements

## Critical Rules

1. **This project MUST be implemented entirely in GDScript**
2. **This project MUST use Godot 4.x GDScript syntax**
3. **GDScript is NOT Python - do not confuse them**
4. **All classes MUST explicitly declare inheritance** (e.g., `extends RefCounted`, `extends Node`, `extends Resource`) - no implicit inheritance
5. **No emojis allowed** - Do not use any emoji characters in code, strings, comments, or UI text

## Strict Type Checking

This project treats GDScript type warnings as errors (`project.godot` settings):

- `inferred_declaration=2` — `:=` is forbidden. Always use explicit types: `var x: String = "hello"`
- `untyped_declaration=2` — all variables, parameters, and return types must have explicit type annotations
- `unsafe_method_access=2` — calling methods on `Variant` is an error. Cast first: `var btn: Button = node as Button`
- `unsafe_property_access=2` — accessing properties on `Variant` is an error. Cast first

Common pitfalls:
- `Dictionary.get()` returns `Variant`. Assign to a typed variable before passing to typed functions
- `is` checks do not narrow the type. After `if event is InputEventMouseButton:`, you still need `var mb: InputEventMouseButton = event as InputEventMouseButton`
- Use `@warning_ignore("unsafe_cast")` or `@warning_ignore("unsafe_method_access")` only when unavoidable (e.g., accessing autoload methods from a generic `Node` reference)

## Best Practice: Use SceneSystem

Always use `SceneSystem` for scene operations (see `coding.md`). Never use native Godot methods like `get_tree().change_scene_to_file()`.

## Engine-Level GDScript Knowledge

For Godot engine rules beyond this project's conventions, use `search_knowledge_base` with `category_key="godot_engine"`.
