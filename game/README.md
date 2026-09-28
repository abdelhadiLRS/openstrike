# OpenStrike Prototype

Original Godot 4 vertical slice for the OpenStrike project.

## Current systems

- Two-team foundation: BLUE player team and RED opposing team
- Team-aware target damage filtering
- Multiple BLUE player spawn points
- Multiple RED enemy spawn points
- 10-second buy phase before combat
- Original round economy with persistent credits
- AR-17 and PX-9 purchase costs
- Round win/loss and elimination rewards
- Live combat phase with a 120-second round timer
- Post-round result phase with automatic next-round start
- Round score tracking
- Player health and death state
- Automatic respawn after player death
- Round win condition when all opposing targets are eliminated
- Round loss condition when the timer expires
- Bomb objective with original A/B sites
- Hold F to plant at an objective site
- 30-second planted-bomb countdown
- Hold F to defuse at the planted site
- Objective win conditions for detonation and defusal
- Round reset and target restoration
- First-person movement and mouse look
- Jumping
- Crouch movement with reduced player height and camera height
- Two original weapon profiles: AR-17 and PX-9
- Buy-phase weapon selection and primary purchase
- Weapon switching
- Magazine and reserve ammunition per weapon
- Reload
- Hitscan shooting
- Per-weapon damage, fire delay, and recoil
- Three RED combat bots with health, detection, line-of-sight, shooting, and death states
- Waypoint-based bot navigation between defensive objective sites
- RED bots switch to planted-site defense and attack the BLUE player when detected
- Damageable combat units
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
- 1: buy/select AR-17 during buy phase
- 2: select PX-9 during buy phase
- F: hold to plant/defuse the bomb at an objective site
- ESC: release mouse

This prototype uses original code and procedurally generated geometry. It does not use Counter-Strike proprietary code or assets.

Open the `game/` directory in Godot 4 and run `main.tscn`.

## Architecture direction

The tactical match foundation is now organized around:

1. team identity
2. spawn selection
3. round state machine
4. player health/death
5. weapon and ammunition layer
6. economy/buy layer
7. objective/bomb mode
8. bots and navigation
9. LAN multiplayer
10. dedicated server

The current enemy units are original RED combat bots. Their navigation uses a lightweight waypoint graph suited to the procedural graybox, while direct line-of-sight is used for combat. Full multiplayer navigation remains a separate layer.
