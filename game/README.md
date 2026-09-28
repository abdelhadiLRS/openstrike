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


### Adaptive bot route replanning
- Bots now retain the current route goal and periodically re-evaluate navigation instead of following a stale path indefinitely.
- Significant goal movement triggers an immediate route rebuild.
- A short replan interval keeps dynamic tactical movement responsive while avoiding per-frame pathfinding.


### Dynamic combat slot reassignment
- Combat slots are refreshed on a short tactical interval instead of remaining permanently tied to bot spawn order.
- Active bots are classified relative to the BLUE player's current lateral view: left, right, and center.
- When the player changes direction or the bots reposition around them, slot ownership can change so the attack-angle selector continues to distribute pressure around the current player position.
- Single- and two-bot states degrade cleanly to center or left/right slots without requiring a full three-bot squad.

### Coordinated combat angle assignment
- Combat repositioning now uses explicit left/right/center tactical slots.
- Bots penalize positions already occupied or reserved by another bot's reposition goal.
- Near-but-not-identical positions receive a softer separation penalty instead of being discarded immediately, preserving fallback options when the map is constrained.
- Attack-angle scoring now favors lateral separation around the player so bots are less likely to stack behind the same peek point.
- Existing adaptive route replanning continues to rebuild the route when the selected combat position changes.

### Dynamic combat assignment
- Active RED bots now receive a tactical combat assignment independently from their geometric left/center/right slot.
- One bot is selected as **PRESSURE** using current distance, health, and center-slot proximity; this bot is the primary aggressor when it has a viable engagement.
- A second bot becomes **SUPPORT**, with lower-health units naturally tending toward this assignment instead of being forced into the first push.
- The remaining bot becomes **FLANK**, using wider engagement conditions so pressure can come from a different angle rather than all bots chasing the same line.
- Assignments refresh on a throttled interval and integrate with the existing combat-intent, repositioning, cover, and dynamic slot systems.
- With one or two surviving bots, the assignment set degrades cleanly without requiring a full squad.


### Squad engagement handoff
- Combat assignments now include an engagement role in addition to PRESSURE / SUPPORT / FLANK.
- PRESSURE is treated as the current lead attacker, while SUPPORT is deliberately held from making the same push at the same time.
- If the lead attacker is removed, the next assignment cycle promotes a surviving bot into PRESSURE and rebuilds the supporting roles around the new lead.
- FLANK retains independent wider-angle pressure so the squad does not collapse into a single chase line.
- Assignment selection has light role persistence to reduce unnecessary role swapping when several bots have similar scores.
- Bomb DEFUSE and BOMB_COVER states still take precedence over the normal squad engagement layer.


### Squad tactical memory
- The RED squad now keeps a short-lived shared memory of the player's last confirmed position when at least one surviving bot has line of sight.
- The memory expires after a short timeout instead of becoming permanent information.
- Attack repositioning can use the remembered position when the player has moved behind cover, allowing the squad to pressure the last known area rather than instantly treating the target as continuously visible.
- The memory is shared across bots and carries a revision number so later tactical systems can react to meaningful updates.
- The system remains bounded by a maximum tactical distance and does not create persistent map-wide player tracking.


### Last-known-position squad coordination
- Engagement targeting now distinguishes the three squad assignments when the player is temporarily hidden.
- PRESSURE works from the remembered player position directly.
- SUPPORT receives a small offset to avoid collapsing onto the pressure lane.
- FLANK receives a wider lateral offset based on its combat slot, creating a separate approach lane around the last-known position.
- When a bot has fresh line of sight, the real player position remains authoritative and the memory offsets are not applied.

### Squad search and sweep
- When the shared tactical memory expires without a fresh line of sight, the squad enters a bounded search window around the last confirmed player position.
- PRESSURE searches the center lane, while SUPPORT and FLANK search opposite lateral sectors instead of converging on one point.
- Search goals advance through short forward sweeps on a throttled revision interval, creating a simple three-sector sweep rather than a static waypoint.
- A fresh visual contact immediately cancels the search and returns normal combat intent to the squad.
- Search state never overrides planted-bomb defuse or bomb-cover priority.

### Search → contact → re-engage
- During a squad search, any bot that regains a direct line of sight publishes a short-lived shared contact report with the observed player position.
- The contact report immediately cancels the search and refreshes the squad's tactical memory and last-known position.
- Bots without direct vision enter a bounded REENGAGE state and move toward the shared contact target instead of returning to an obsolete search point.
- PRESSURE, SUPPORT, and FLANK keep using the shared engagement-target offsets, so re-engagement preserves squad separation rather than collapsing every bot onto the reporter.
- Combat assignments are refreshed when the contact revision changes, allowing the squad to redistribute roles as soon as a new contact is reported.
- The contact memory expires after 4 seconds without a fresh report; planted-bomb defuse and bomb-cover states retain priority over contact behavior.


### Squad Combat Director
- A lightweight combat director now coordinates the squad through contact timing instead of allowing every bot to attack simultaneously.
- The first contact window gives the PRESSURE bot immediate firing authority, while SUPPORT waits briefly before entering a controlled suppression phase.
- FLANK receives a later firing window, creating a short stagger between the lead attack, supporting fire, and the wider-angle flank.
- SUPPORT uses a dedicated `SUPPRESS` movement state and holds its engagement lane instead of blindly joining the pressure bot's chase.
- The director exposes a revision and phase to each bot, so contact changes can invalidate stale coordination without replacing the existing bomb-objective priorities.
- When contact is lost, the director falls back through SEARCH/LOST phases while the existing tactical-memory and re-engagement systems continue to control movement.


### Combat command bus and flank execution
- The combat director now publishes an explicit command per bot: `PUSH`, `SUPPRESS`, `FLANK`, or `HOLD`.
- FLANK has its own movement state and uses the existing attack-position selector to seek a separated angle instead of following the pressure lane.
- SUPPORT remains in `SUPPRESS` and receives its own delayed firing authority.
- The command is refreshed from the shared contact revision, so a new contact or reassignment can immediately replace stale squad orders.


### Dynamic combat handoff
- Squad combat roles are now reassigned from the currently alive bots instead of assuming the original three-bot lineup survives.
- The existing PRESSURE role is preserved when its bot is alive; when that bot is eliminated, another active bot is promoted to PRESSURE.
- SUPPORT and FLANK roles are then redistributed among the remaining bots, with role changes marked as `HANDOFF` so stale engagement intent can be replaced.
- The reassignment runs without changing bomb-objective priority and works with the existing contact revision/director timing system.


### Role-versioned combat handoff
- Combat role changes now carry a squad-wide role revision so bots can invalidate stale movement and firing state immediately after a promotion or reassignment.
- A promoted PRESSURE, SUPPORT, or FLANK bot clears its previous attack/reposition route before executing the new command.
- The director temporarily suppresses firing authority on the handoff tick, preventing a bot from firing with stale role timing while its new angle is being selected.
- This keeps role promotion synchronized with the existing contact revision and Combat Director systems.
