#!/usr/bin/env python3
"""
Generate pck_info.json files from manifest.json configurations.

This script runs BEFORE any Godot command to ensure FontSystem etc. can read
valid pck_info.json files during initialization.

The pck_info.json generated here contains the file list but not hash/pck_file.
pack_assets.gd will later update these fields after creating the PCK files.

Usage:
    python tools/generate_pck_info.py
"""

import json
import os
from pathlib import Path


def generate_key(filename: str) -> str:
    """Generate key from filename (same logic as pack_assets.gd to_snake_case)."""
    # Remove extension
    base = Path(filename).stem
    
    # Convert to snake_case (matching Godot's to_snake_case behavior)
    result = ""
    prev_was_upper = False
    prev_was_underscore = True  # Treat start as after underscore
    
    for c in base:
        if c in "-_ ":
            if not prev_was_underscore:
                result += "_"
            prev_was_underscore = True
            prev_was_upper = False
        elif c.isupper():
            if not prev_was_underscore and not prev_was_upper:
                result += "_"
            result += c.lower()
            prev_was_upper = True
            prev_was_underscore = False
        else:
            result += c.lower()
            prev_was_upper = False
            prev_was_underscore = False
    
    # Clean up double underscores
    while "__" in result:
        result = result.replace("__", "_")
    
    return result.strip("_")


def scan_files(directory: Path, extensions: list) -> list:
    """Scan directory for files with given extensions."""
    files = []
    for item in directory.iterdir():
        if item.is_file():
            ext = item.suffix.lstrip(".").lower()
            if ext in extensions:
                files.append(item.name)
    return sorted(files)


def process_asset_dir(asset_dir: Path, pck_infos_dir: Path) -> bool:
    """Process a single asset directory."""
    manifest_path = asset_dir / "manifest.json"
    # Output to public/pck_infos/<type>.json
    pck_info_path = pck_infos_dir / f"{asset_dir.name}.json"
    
    if not manifest_path.exists():
        return False
    
    # Read manifest
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    
    extensions = manifest.get("extensions", [])
    internal_prefix = manifest.get("internal_prefix", f"res://{asset_dir.name}/")
    default_key = manifest.get("default", "")
    
    if not extensions:
        print(f"  Skipping {asset_dir.name}: no extensions defined")
        return False
    
    # Scan files
    files = scan_files(asset_dir, extensions)
    if not files:
        print(f"  Skipping {asset_dir.name}: no matching files")
        return False
    
    # Build file entries
    file_entries = []
    for filename in files:
        key = generate_key(filename)
        path = internal_prefix + filename
        file_entries.append({"key": key, "path": path})
    
    # Build pck_info
    pck_info = {
        "pck_file": "",  # Will be filled by pack_assets.gd
        "hash": "",      # Will be filled by pack_assets.gd
    }
    
    # Add default_font for fonts directory (FontSystem expects this)
    if default_key:
        if asset_dir.name == "fonts":
            pck_info["default_font"] = default_key
        else:
            pck_info["default"] = default_key
    
    # Use "fonts" key for fonts, "files" for others (FontSystem compatibility)
    if asset_dir.name == "fonts":
        pck_info["fonts"] = file_entries
    else:
        pck_info["files"] = file_entries
    
    # Write pck_info json
    with open(pck_info_path, "w", encoding="utf-8") as f:
        json.dump(pck_info, f, indent=2, ensure_ascii=False)
    
    print(f"  Generated: {pck_info_path.relative_to(pck_infos_dir.parent.parent)} ({len(file_entries)} files)")
    return True


def main():
    # Find project root (parent of scripts/)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    assets_root = project_root / "public" / "assets"
    pck_infos_dir = project_root / "public" / "pck_infos"
    
    if not assets_root.exists():
        print(f"Assets directory not found: {assets_root}")
        return 1
    
    # Ensure pck_infos directory exists
    pck_infos_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating pck_info files to public/pck_infos/...")
    
    count = 0
    for item in assets_root.iterdir():
        if item.is_dir() and not item.name.startswith("."):
            if process_asset_dir(item, pck_infos_dir):
                count += 1
    
    print(f"Generated {count} pck_info files in public/pck_infos/")
    return 0


if __name__ == "__main__":
    exit(main())

