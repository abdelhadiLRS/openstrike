# Building OpenStrike

OpenStrike is a Godot 4 project. The game project is located in `game/`; its main scene is `res://main.tscn` and the renderer is Godot's Compatibility renderer.

## Run locally

1. Install Godot 4.4.1 or a compatible Godot 4 release.
2. Open `game/project.godot` in Godot, or launch from a terminal:

```sh
godot --path game
```

## Headless validation

Run these commands from the repository root to import project resources and check that the main scene starts without a display:

```sh
godot --headless --editor --path game --quit
godot --headless --path game --quit-after 3
```

The GitHub Actions workflow runs the same checks on pushes and pull requests that touch `game/`.

## Visual quality presets

- Default: HIGH visual quality.
- `--balanced-visual`: atmospheric fog and dust, with glow and shadow maps disabled.
- `--low-spec`: disables fog, shadow maps, and selected decorative effects for integrated graphics.
- Press **F4** in-game to cycle HIGH → BALANCED → LOW.

Examples:

```sh
godot --path game -- --balanced-visual
godot --path game -- --low-spec
```

## Exporting a desktop build

No checked-in `export_presets.cfg` or export templates are currently provided. To export a Windows or Linux build, install the matching Godot export templates, open the project in the Godot editor, and configure the desired preset under **Project → Export**. Choose an output path outside source folders (for example, `build/OpenStrike.exe` on Windows). Keep generated binaries and Godot's local editor cache out of version control.
