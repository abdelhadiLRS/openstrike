# OpenStrike Prototype

Original Godot 4 vertical slice for the OpenStrike project.

## Current systems

- Player health and death state
- Automatic respawn after player death
- Timed round lifecycle
- Round win condition when all training targets are eliminated
- Round reset and target restoration

- First-person movement and mouse look
- Jumping
- Crouch movement with reduced player height and camera height
- Two original weapon profiles: AR-17 and PX-9
- Weapon switching
- Magazine and reserve ammunition per weapon
- Reload
- Hitscan shooting
- Per-weapon damage, fire delay, and recoil
- Damageable training targets
- Procedural graybox training range
- Minimal HUD and crosshair
- Godot Compatibility renderer

## Controls

- WASD: move
- CTRL: crouch
- SPACE: jump
- Left mouse: fire
- R: reload
- E: switch weapon
- ESC: release mouse

This prototype uses original code and procedurally generated geometry. It does not use Counter-Strike proprietary code or assets.

Open the `game/` directory in Godot 4 and run `main.tscn`.

## Next development layer

The next gameplay systems are planned around a proper tactical match architecture:

1. player health and death state
2. team and spawn system
3. round lifecycle
4. buy/economy layer
5. objective/bomb mode
6. bots and navigation
7. LAN multiplayer
8. dedicated server
