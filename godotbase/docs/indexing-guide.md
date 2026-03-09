# Project Indexing Guide

This project uses structured JSON indices to provide fast navigation of scenes, scripts, and project structure. Always query these indices before reading source files to reduce I/O and improve accuracy.

## Index Files Location

All index files are in `.agent_index/` directory:

```
.agent_index/
├── repo_map.json          # Project metadata and entry points
├── scene_map.json         # Scene structure and node-script relationships
├── script_symbols.json    # Script symbols (classes, functions, signals)
├── patch_log.jsonl        # Modification history (one JSON per line)
└── index_state.json       # Index metadata and timestamps
```

## Standard Query Workflow

**Always follow this sequence:**

```
Task: Modify game behavior
│
├─ 1. Read .agent_index/repo_map.json
│  └─ Find: entrypoints.main_scene, autoloads, directory tags
│
├─ 2. Read .agent_index/scene_map.json
│  └─ Find: relevant nodes and their attached scripts
│
├─ 3. Read .agent_index/script_symbols.json
│  └─ Find: functions, signals, exports in those scripts
│
└─ 4. Read source files (only specific line ranges)
   └─ Use: functions[].range to read relevant sections only
```

## Index File Schemas

### repo_map.json

Project-level metadata.

**Key fields:**
```json
{
  "entrypoints": {
    "main_scene": "res://main.tscn"
  },
  "autoloads": [
    {"name": "Globals", "path": "res://autoload/Globals.gd"}
  ],
  "directories": [
    {"path": "res://scenes", "tag": "core", "purpose": "game scenes"},
    {"path": "res://addons", "tag": "addon", "purpose": "avoid editing"}
  ]
}
```

**Usage:**
- Find entry scene: `repo_map["entrypoints"]["main_scene"]`
- Check autoload singletons: `repo_map["autoloads"]`
- Identify safe-to-edit directories: filter `directories` by `tag == "core"`

### scene_map.json

Scene structure and dependencies.

**Key fields:**
```json
{
  "scenes": {
    "res://scenes/Main.tscn": {
      "nodes": [
        {"path": "Player", "type": "CharacterBody2D", "script": "res://scripts/Player.gd"},
        {"path": "UI/HUD", "type": "CanvasLayer", "instancedScene": "res://ui/HUD.tscn"}
      ],
      "externalScenes": ["res://ui/HUD.tscn"]
    }
  }
}
```

**Usage:**
- Find nodes in scene: `scene_map["scenes"][scene_path]["nodes"]`
- Find script attached to node: filter `nodes` by `path`, get `script` field
- Find instanced scenes: `scene_map["scenes"][scene_path]["externalScenes"]`

### script_symbols.json

Script symbols and structure.

**Key fields:**
```json
{
  "scripts": {
    "res://scripts/Player.gd": {
      "class_name": "Player",
      "extends": "CharacterBody2D",
      "signals": ["died", "health_changed"],
      "exports": [
        {"name": "speed", "type_hint": "float"}
      ],
      "functions": [
        {"name": "_ready", "range": {"start": 15, "end": 20}},
        {"name": "jump", "range": {"start": 82, "end": 110}}
      ],
      "preloads": ["res://scenes/Bullet.tscn"],
      "dependencies": ["res://scripts/Damageable.gd"]
    }
  }
}
```

**Usage:**
- Find function location: `symbols["scripts"][path]["functions"]`, use `range` to read specific lines
- Check inheritance: `symbols["scripts"][path]["extends"]`
- Find signals: `symbols["scripts"][path]["signals"]`
- Check dependencies: `symbols["scripts"][path]["preloads"]` + `["dependencies"]`

### patch_log.jsonl

Modification history. Each line is a separate JSON object.

**Format:**
```jsonl
{"ts":"2024-01-15T10:30:00Z","task":"Fix jump bug","touchedFiles":["res://scripts/Player.gd"],"result":"success","notes":"Adjusted timing"}
```

**Usage:**
- Read line-by-line to see recent changes
- Check which files were modified for specific tasks
- Understand modification patterns

## Query Rules

### RULE 1: Always Query Indices First

**Good:**
```
1. Load scene_map.json
2. Find scripts attached to Player nodes
3. Load script_symbols.json for those scripts
4. Read only relevant function line ranges
```

**Bad:**
```
1. Glob search all .gd files
2. Read entire files looking for Player code
```

### RULE 2: Limit File Reading Scope

Use indices to narrow down to **3-8 candidate files maximum** before reading source.

**Example:**
```
Task: Find health system code

1. Check script_symbols.json for scripts with "health" signals
   → Found 3 scripts: Player.gd, Enemy.gd, Damageable.gd

2. Check scene_map.json to see which scenes use these scripts
   → Player.gd used in Main.tscn

3. Read only these 3 scripts (not all 50 scripts in project)
```

### RULE 3: Use Line Ranges for Functions

Script symbols include line ranges. Read only relevant sections.

**Example:**
```python
# Get function location
symbols = json.load('.agent_index/script_symbols.json')
jump_func = [f for f in symbols['scripts']['res://scripts/Player.gd']['functions'] 
             if f['name'] == 'jump'][0]

# Read only that function (lines 82-110, not entire file)
read_file('scripts/Player.gd', 
          offset=jump_func['range']['start'], 
          limit=jump_func['range']['end'] - jump_func['range']['start'])
```

### RULE 4: Verify Scene Wiring for Script Changes

When modifying script behavior, check scene structure for dependencies.

**Example:**
```
Task: Add new signal to Player.gd

1. Check scene_map.json for scenes using Player.gd
2. Verify no hardcoded node path assumptions
3. Make script changes
4. Check if any scenes connect to Player signals
```

## Common Query Patterns

### Pattern: Find Entry Scene

```python
repo_map = json.load('.agent_index/repo_map.json')
main_scene = repo_map['entrypoints']['main_scene']
```

### Pattern: Find Script by Node Name

```python
scene_map = json.load('.agent_index/scene_map.json')
main_scene_data = scene_map['scenes']['res://main.tscn']

# Find Player node
player_node = [n for n in main_scene_data['nodes'] if 'Player' in n['path']][0]
player_script = player_node['script']  # "res://scripts/Player.gd"
```

### Pattern: Find Function in Script

```python
symbols = json.load('.agent_index/script_symbols.json')
player_symbols = symbols['scripts']['res://scripts/Player.gd']

# Find jump function
jump_func = [f for f in player_symbols['functions'] if f['name'] == 'jump'][0]
# jump_func['range'] = {"start": 82, "end": 110}
```

### Pattern: Find All Scripts with Signal

```python
symbols = json.load('.agent_index/script_symbols.json')
scripts_with_died_signal = []

for script_path, script_data in symbols['scripts'].items():
    if 'died' in script_data['signals']:
        scripts_with_died_signal.append(script_path)
```

### Pattern: Find Scene Dependencies

```python
scene_map = json.load('.agent_index/scene_map.json')
main_scene_data = scene_map['scenes']['res://main.tscn']

# Get directly instanced scenes
instanced_scenes = main_scene_data['externalScenes']
# ["res://ui/HUD.tscn", "res://player/Player.tscn"]
```

### Pattern: Check Script Inheritance

```python
symbols = json.load('.agent_index/script_symbols.json')

# Find all CharacterBody2D subclasses
character_scripts = []
for script_path, script_data in symbols['scripts'].items():
    if script_data['extends'] == 'CharacterBody2D':
        character_scripts.append(script_path)
```

## Task-Specific Workflows

### Workflow: Fix Gameplay Bug

```
1. Load repo_map.json → find main_scene
2. Load scene_map.json → find gameplay nodes and scripts
3. Load script_symbols.json → locate relevant functions by name
4. Read source file lines within function ranges only
5. Make changes
6. Indices are automatically updated on next build
```

### Workflow: Add New Feature

```
1. Load repo_map.json → understand project structure
2. Load scene_map.json → identify scenes to modify
3. Load script_symbols.json → check for similar existing features
4. Create new scripts/scenes
5. Indices are automatically updated on next build
```

### Workflow: Refactor Code

```
1. Load script_symbols.json → find all usages of target symbol
2. Load scene_map.json → identify scenes using affected scripts
3. Read source files for affected functions only
4. Perform refactoring
5. Verify scene wiring still valid
6. Indices are automatically updated on next build
```

## Performance Guidelines

**Efficient index usage:**

- Load JSON files once per task
- Use indices to narrow scope to < 10 files
- Read specific line ranges using `functions[].range`
- Cache loaded indices in memory during task

**Avoid:**

- Reading entire script files without checking indices
- Glob searching filesystem when indices exist
- Ignoring line range information
- Loading indices multiple times

## Index Updates

**Indices are automatically updated during build process.**

You do not need to manually regenerate indices. They update incrementally when you run the build script.

If indices are missing or outdated, they will be regenerated automatically on next build.

## Error Handling

**If index files are missing:**
- Fallback to manual file exploration
- Next build will generate indices

**If index data seems incorrect:**
- Check `.agent_index/index_state.json` for generation timestamp
- Wait for next build to regenerate

**If you cannot find expected data:**
- Check that indices are up to date (compare timestamps)
- Verify file paths use `res://` prefix
- Check scene_map for node path format (uses "/" separator)

