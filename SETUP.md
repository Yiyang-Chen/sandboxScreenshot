# Sandbox Headless Screenshot Setup

## Quick Start

```bash
./setup.sh
```

This single script installs all system dependencies (Mesa, Xvfb, X11 libraries), downloads Godot 4.5.1, and configures the web export template.

## What Gets Installed

- **Godot 4.5.1** at `/root/tools/godot/godot`
- **Xvfb** (virtual framebuffer) for headless rendering
- **Mesa llvmpipe** for CPU-based OpenGL 3.3 software rendering
- **X11/XCB libraries** required by Godot's display server
- **Web export template** copied to Godot's template directory

## After Setup

Run a screenshot test to verify:

```bash
bash godotbase/tests/framework/run_test.sh framework/example_test.gd
```

See `godotbase/tests/test-runner.md` for the full test runner documentation.

## Key Files

| File | Description |
|------|-------------|
| `setup.sh` | One-step environment setup |
| `godot_env.sh` | Shared environment variables (sourced by `run_capture.sh`) |
| `run_capture.sh` | Quick one-shot screenshot capture |
| `godotbase/tests/framework/run_test.sh` | Test runner for agent-authored test scripts |
| `godotbase/tests/framework/test_runner.gd` | TestRunner base class |
| `godotbase/tests/test-runner.md` | Test runner documentation for agents |
