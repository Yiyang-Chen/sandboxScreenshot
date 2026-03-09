# Sandbox Headless Screenshot Setup

This document describes how to set up a headless Linux environment to run a Godot 4.5.1 project, capture screenshots via software rendering, and export the project for Web.

## Prerequisites

### Godot Engine

Download Godot 4.5.1 stable for Linux x86_64 and place the binary at `/root/tools/godot/godot`:

```bash
mkdir -p /root/tools/godot
curl -L -o /tmp/godot.zip \
  https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/godot.zip').extractall('/root/tools/godot')"
mv /root/tools/godot/Godot_v4.5.1-stable_linux.x86_64 /root/tools/godot/godot
chmod +x /root/tools/godot/godot
```

### Web Export Template

Copy the custom web export template so Godot can find it:

```bash
mkdir -p ~/.local/share/godot/export_templates/4.5.1.stable
cp templates/web_nothreads_release_no_wasm.zip \
   ~/.local/share/godot/export_templates/4.5.1.stable/
```

The path must match `custom_template/release` in `godotbase/export_presets.cfg`.

## System Dependencies

All packages below are for Ubuntu 24.04 (Noble) x86_64. Install via `apt-get install` or, in restricted environments, by manually downloading `.deb` files and extracting with `dpkg-deb -x`.

### Xvfb and X11

Provides a virtual X11 display so Godot can initialize its rendering pipeline without a physical monitor.

| Package | Purpose |
|---------|---------|
| `xvfb` | X virtual framebuffer server |
| `x11-xkb-utils` | Provides `xkbcomp` (required by Xvfb) |
| `xkb-data` | Keyboard layout data |

### Mesa / OpenGL (Software Rendering)

Mesa's `llvmpipe` Gallium driver provides pure-CPU OpenGL 3.3 rendering -- no GPU required.

| Package | Purpose |
|---------|---------|
| `libgl1-mesa-dri` | Mesa DRI drivers including `swrast_dri.so` (llvmpipe) |
| `libegl-mesa0` | Mesa EGL implementation |
| `libegl1` | EGL loader (glvnd) |
| `libglx-mesa0` | Mesa GLX implementation |
| `libgbm1` | Generic buffer management |
| `mesa-vulkan-drivers` | Lavapipe software Vulkan (optional, used as fallback) |

### LLVM

Mesa's llvmpipe JIT-compiles shaders via LLVM. The LLVM major version must match the one Mesa was built against.

| Package | Purpose |
|---------|---------|
| `libllvm17t64` | LLVM 17 shared library required by llvmpipe on Ubuntu 24.04 Mesa |

### DRM

Direct Rendering Manager libraries used by Mesa internally.

| Package | Purpose |
|---------|---------|
| `libdrm2` | Core DRM library |
| `libdrm-intel1` | Intel DRM support (loaded by `swrast_dri.so`) |
| `libdrm-amdgpu1` | AMD DRM support |
| `libdrm-nouveau2` | Nouveau DRM support |
| `libdrm-radeon1` | Radeon DRM support |
| `libpciaccess0` | PCI bus access (transitive dependency of `libdrm-intel1`) |

### X11 Client Libraries

Godot's X11 display server dynamically loads these at startup.

| Package | Purpose |
|---------|---------|
| `libxcursor1` | X cursor management |
| `libxi6` | X Input extension |
| `libxrandr2` | X Resize and Rotate extension |
| `libxinerama1` | X multi-monitor extension |
| `libx11-xcb1` | X11/XCB interop (required by Mesa EGL) |

### XCB Extensions

| Package | Purpose |
|---------|---------|
| `libxcb-cursor0` | XCB cursor support |
| `libxcb-icccm4` | ICCCM window manager hints |
| `libxcb-keysyms1` | XCB key symbol helpers |

### Other

| Package | Purpose |
|---------|---------|
| `libxkbcommon0` | Keyboard keymap compilation |
| `libasound2t64` | ALSA audio (Godot loads it; not strictly required for screenshots) |
| `fontconfig` | Font discovery and configuration |

## Headless Screenshot Capture

### Quick Start

```bash
./run_capture.sh --scene res://scenes/main.tscn --out /tmp/frame.png --frames 10
```

This starts Xvfb, launches Godot with software OpenGL, loads the specified scene, waits for warmup frames, saves a PNG screenshot, and shuts down.

### Command-Line Arguments

All arguments are passed through to `capture_runner.gd` after the `--` separator.

| Argument | Default | Description |
|----------|---------|-------------|
| `--scene` | `res://scenes/main.tscn` | Godot scene to load and capture |
| `--out` | *(required)* | Output PNG file path |
| `--frames` | `5` | Number of warmup frames before capture |
| `--width` | `1280` | Viewport width in pixels |
| `--height` | `720` | Viewport height in pixels |

### How It Works

`run_capture.sh` performs these steps:

1. Sets environment variables for Mesa software rendering (see below).
2. Starts Xvfb on display `:99` with a 1280x720x24 virtual screen.
3. Runs Godot with `--rendering-driver opengl3` and the `-s tools/capture_runner.gd` script.
4. `capture_runner.gd` (extends `SceneTree`) loads the target scene, waits N frames for rendering to stabilize, grabs the viewport texture, saves it as PNG, and calls `quit()`.
5. Cleans up the Xvfb process on exit.

## Web Export

Run the following command to export the project to HTML5:

```bash
/root/tools/godot/godot --headless --path godotbase --export-release "Web"
```

Output files are written to `godotbase/dist/` (as configured by `export_path` in `export_presets.cfg`).

The export uses the custom template at `~/.local/share/godot/export_templates/4.5.1.stable/web_nothreads_release_no_wasm.zip`, which is a no-threads, no-WASM variant suitable for broad browser compatibility.

## Environment Variables

`run_capture.sh` configures these environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `LD_LIBRARY_PATH` | `/root/localroot/usr/lib/x86_64-linux-gnu:...` | Library search path for manually installed packages |
| `LIBGL_DRIVERS_PATH` | `/root/localroot/usr/lib/x86_64-linux-gnu/dri` | Where Mesa looks for DRI driver `.so` files |
| `LIBGL_ALWAYS_SOFTWARE` | `1` | Force Mesa to use software rendering |
| `GALLIUM_DRIVER` | `llvmpipe` | Select the llvmpipe CPU-based Gallium driver |
| `MESA_GL_VERSION_OVERRIDE` | `3.3` | Report OpenGL 3.3 (Godot's minimum for `opengl3` driver) |
| `MESA_GLSL_VERSION_OVERRIDE` | `330` | Report GLSL 330 to match the GL version |
| `XKB_CONFIG_ROOT` | `/root/localroot/usr/share/X11/xkb` | Keyboard layout data path for Xvfb |
| `GODOT_SILENCE_ROOT_WARNING` | `1` | Suppress Godot's "running as root" warning |
| `DISPLAY` | `:99` | Connect to the Xvfb virtual display |

## Key Files

| File | Description |
|------|-------------|
| `run_capture.sh` | Shell script that starts Xvfb, sets up the rendering environment, and launches Godot with the capture script |
| `godotbase/tools/capture_runner.gd` | GDScript (`extends SceneTree`) that loads a scene, waits for warmup frames, captures the viewport to PNG, and exits |
| `godotbase/export_presets.cfg` | Godot export configuration for the "Web" preset, pointing to the custom release template |
| `templates/web_nothreads_release_no_wasm.zip` | Custom Godot web export template (no threads, no WASM) |
