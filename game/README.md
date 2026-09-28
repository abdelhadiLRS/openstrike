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
- Bomb drops at the player's death position and can be recovered after respawn with a dedicated pickup radius
- Visible original bomb entity with dropped/planted world states and planted-state blinking light
- Planted-bomb defense distributes RED bots between one active defuser and separate tactical cover positions
- Bomb-cover assignments persist for the planted site instead of being recalculated every frame
- Each bomb site has dedicated tactical cover anchors, with LOS and occupancy validation before assignment
- Bomb-defense assignments are revisioned so a replacement defuser invalidates stale cover assignments
- A/B site defenders score cover using player approach direction and role-aware spacing, while the roamer uses a different tactical bias
- Bomb-cover defenders hold their assigned angle, face the BLUE player, and apply controlled lateral movement while maintaining the defensive position
- RED bots use a throttled tactical combat-intent layer: HOLD, PUSH, or RETREAT based on health, distance, line-of-sight, role, and site proximity
- Low-health bots prioritize validated cover instead of continuously chasing the player
- Roamers can pressure visible targets at a larger tactical distance, while site defenders only push aggressively when the player is close to their assigned site
- Bomb recovery uses a tighter pickup radius than the plant/defuse site radius
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

### Combat reaction and repositioning
- Bots now react to recent hits with a short break-contact window, especially when health is already reduced.
- Retreating bots select validated combat cover instead of blindly reusing a generic cover slot.
- Combat cover selection checks line of sight, usable peek geometry, travel distance, and occupancy by other bots so multiple enemies are less likely to stack on one position.
- A retreating bot remains behind cover rather than immediately entering the peek cycle, reducing exposed re-peeks while under pressure.

### Coordinated combat repositioning
- Bots now use stable combat slots so defenders and the roamer seek different attack angles instead of converging on the same peek position.
- Attackers periodically request a new validated peek position after a short reposition interval, with occupancy and line-of-sight checks.
- Repositioning is a dedicated movement state, so the bot can travel to the new angle without immediately cancelling the maneuver through the normal combat-intent loop.
- The shared selector favors useful lateral separation around the player while preserving cover-to-peek geometry.


### Navigation and pathfinding
- The procedural waypoint network is now compiled into a static visibility graph after the graybox geometry is created.
- Bot route selection uses A* with Euclidean distance as the heuristic instead of breadth-first search, so longer detours are compared by travel cost.
- Start and goal anchors still require direct visibility, while the cached graph handles repeated static-obstacle routing more efficiently.


### Navigation route smoothing
- A* routes are now post-processed with line-of-sight checks to remove unnecessary intermediate waypoints.
- Bots therefore keep the obstacle-safe route while taking straighter segments whenever the graybox geometry allows it.
