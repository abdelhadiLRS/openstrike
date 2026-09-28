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
- Three RED combat bots with role-based defense, detection, line-of-sight, shooting, and death states
- RED bot combat roles: Defender A, Defender B, and Roamer
- Combat standoff range, retreat behavior, strafing, burst fire, and accuracy spread
- Obstacle-aware graph navigation between defensive objective sites
- Procedural cover points with LOS-validated low-health retreat and bounded peek behavior
- RED bots switch to planted-site defense and attack the BLUE player when detected
- RED defenders select cover positions around their assigned A/B site, while the roamer rotates between sites
- Planted-bomb defuse uses an explicit active defuser instead of a shared anonymous timer
- Bomb drops at the player's death position and can be recovered after respawn
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

The current enemy units are original RED combat bots. Their navigation uses a lightweight waypoint graph suited to the procedural graybox, while obstacle-aware graph routing and direct line-of-sight are used for movement and combat. Full multiplayer navigation remains a separate layer.
