> [![Claude Code](https://img.shields.io/badge/Claude_Code-claude--sonnet--4--6-D97757?logo=anthropic&logoColor=white)](https://claude.ai/claude-code)

# GodotZigTemplate

A minimal template for building [Godot 4](https://godotengine.org/) GDExtensions in [Zig](https://ziglang.org/). It wires up the GDExtension C API directly — no third-party bindings library required.

## What's included

- **`source/gdext.zig`** — thin wrapper around the GDExtension C API (proc-address loading, string helpers, `print`)
- **`source/register.zig`** — comptime class/method/property registration driven by struct metadata
- **`source/hello_node.zig`** — example custom `Node` subclass (`HelloNodeZig`) with a method and a property
- **`source/main.zig`** — extension entry point (`extension_init`)
- **`build.zig`** — builds the extension as a shared library and drops it into `binaries/`
- **`zigtest.gdextension`** — tells Godot where to find the DLL and which symbol is the entry point
- **`scenes/`** — minimal Godot project that instantiates the example node

## Prerequisites

| Tool | Notes |
|------|-------|
| [Zig ≥ 0.15.2](https://ziglang.org/download/) | Matches `minimum_zig_version` in `build.zig.zon` |
| [Godot 4.6+](https://godotengine.org/download/) | Tested with 4.6 |
| `godot_cpp` headers | Only the `core/extension/` directory is needed — point `build.zig` at it |

The build script expects the Godot extension header directory at `G:/libraries/godot/core/extension` by default. Edit the `addIncludePath` call in `build.zig` to match your layout.

## Build

```sh
# Build the DLL
zig build

# Build the DLL and open the project in the Godot editor
zig build run

# Use a specific Godot binary
zig build run -Dgodot=C:/path/to/godot.exe
```

The compiled DLL is placed in `binaries/` which Godot loads via `zigtest.gdextension`.

## Using this as a git submodule (template workflow)

This repo is designed to be consumed as a **git submodule** in a new project. Non-breaking upstream improvements can be pulled in with `git merge` without overwriting your project-specific changes.

### Set up a new project from this template

```sh
# Create your project
mkdir MyGame && cd MyGame
git init

# Add this template as a submodule (or just clone and use as upstream)
# Recommended: copy the template files and set this repo as a remote named "template"
git remote add template https://github.com/you/GodotZigTemplate.git
git fetch template
git merge template/main --allow-unrelated-histories
```

### Pull template updates later

```sh
git fetch template
git merge template/main
# Resolve any conflicts in favour of your project changes, then commit
```

Because the template avoids storing generated or user-specific files (binaries, editor cache, build cache), merges are generally conflict-free for the infrastructure files and only touch code you care about.

## Adding your own GDExtension classes

1. Create a new file in `source/`, e.g. `source/my_node.zig`, following the pattern in `hello_node.zig`.
2. Import it in `source/main.zig` and call `register.registerClass(MyNode)` in `initializeExtension`.
3. Run `zig build` — the new class will be available in Godot.

The struct must expose:
- `godot_name: [:0]const u8` — the name Godot sees
- `godot_base: [:0]const u8` — the base class (e.g. `"Node"`, `"Node2D"`)
- `godot_methods: []const [:0]const u8` — exported method names (must be `pub fn` on the struct)
- `godot_properties: []const register.GodotProperty` — exported properties with getter/setter names

## Project structure

```
GodotZigTemplate/
├── source/
│   ├── main.zig          # Extension entry point
│   ├── gdext.zig         # GDExtension API loader
│   ├── register.zig      # Comptime class registration
│   └── hello_node.zig    # Example custom node
├── scenes/
│   ├── main.tscn         # Root scene
│   └── main.gd           # GDScript exercising HelloNodeZig
├── binaries/             # Built DLLs (gitignored)
├── build.zig             # Zig build script
├── build.zig.zon         # Zig package manifest
├── project.godot         # Godot project file
└── zigtest.gdextension   # GDExtension manifest
```
