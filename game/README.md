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
- Procedural graybox training range with cool ambient lighting and directional shadows
- Visual-only tactical lane markings, perimeter strips, objective-corner markers, and cover accents (no collision changes)
- Industrial perimeter wall panels, hazard accents on cover, and concentric objective-site floor rings (visual-only; no collision or navigation changes)
- RED combatants use a layered low-poly silhouette with vest, head, helmet, and a readable team-color band
- RED combatants now include lightweight shoulder armor, forearm and thigh plates, a chest rig, and a backpack for a more readable tactical silhouette; details are visual-only and share the existing capsule collider
- First-person AR-17/PX-9 geometric viewmodels that follow weapon selection and authoritative network weapon state
- First-person weapon motion adds restrained movement bob, lateral counter-sway, and a short recoil kick; the animation is visual-only and uses no extra physics or lights
- Reloading now dips and rolls the first-person weapon through a short, eased motion; it is visual-only and adds no physics, particles, or lights.
- Accepted local shots eject a small brass casing that tumbles beside the weapon and then shrinks away; the casing is visual-only, short-lived, shadow-free, and uses no collision, rigid bodies, particles, or extra lights.
- First-person weapon silhouettes now include low-poly barrel tubes, muzzle collars, top rails, and contrasting iron sights; all viewmodel parts are visual-only and cast no shadows
- Team-colored spawn-side floor bands, modular concrete seams, and objective approach chevrons improve spatial orientation without changing collision or bot navigation
- HUD match information is displayed in a translucent, high-contrast panel; NetGraph sits separately below it
- Minimal crosshair and hit feedback
- Planting, defusing, and planted-bomb urgency now show a compact bottom-center progress bar with action-specific color; the HUD cue is screen-space only and adds no world geometry or lighting.
- Hit confirmation now shows a brief centered marker; taking damage produces a short, restrained red screen flash. Both effects are screen-space UI only and use no particles or dynamic lights.
- Bullet impacts now produce a tiny emissive spark at the ray-hit point, color-matched to the weapon tracer; the effect self-cleans quickly and adds no physics, particles, persistent decals, or dynamic lights.
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
- F3: toggle the network diagnostics overlay (NetGraph)
- Dynamic center reticle: expands with movement and recoil, tightens while crouched

This prototype uses original code and procedurally generated geometry. It does not use Counter-Strike proprietary code or assets.

Open the `game/` directory in Godot 4 and run `main.tscn`.

### Network launch flags

The prototype remains offline by default. Optional user arguments can start the built-in authoritative host or connect a client without changing the project defaults:

- `--server`: start as the authoritative host
- `--port=27015`: choose the ENet port
- `--max-clients=16`: cap connected clients
- `--bots=3`: choose the number of AI bots (0..15)
  When connected to an authoritative server, the client's bot roster is synchronized from the server snapshot automatically; the snapshot also carries an explicit bot count so partial state arrays cannot silently collapse the roster to zero. Snapshot payloads are versioned. Clients validate raw field types before parsing to prevent silent coercion, then reject incompatible schemas, invalid peer/acknowledgement metadata, unknown round phases, out-of-range pitch, oversized metadata strings, non-finite positions/velocities/angles/timers, invalid health/ammo/credit ranges, malformed or duplicate owned-weapon IDs, and internally inconsistent bot rosters—including invalid bot health, dead-state, state/assignment types, and round mismatches—before applying authoritative state.
- `--connect=127.0.0.1`: connect as a client to a host
- `--help`: print the OpenStrike network launch options

`--server` and `--connect` are mutually exclusive. Invalid combinations are rejected at startup.

Examples:

- Server: `godot --path game -- --server --port=27015 --max-clients=8`
- Client: `godot --path game -- --connect=127.0.0.1 --port=27015`
- Server with a custom bot count: `godot --path game -- --server --port=27015 --bots=5`

The server validates input packet field types before parsing, rejects malformed or oversized weapon identifiers, and refuses negative, stale, future, duplicate, or regressing input ticks; accepted movement and look values are bounded before simulation.

The flags are parsed only at startup; without them the existing offline flow is unchanged.

### Visual polish

- The arena now uses a procedural daylight sky with a blue-to-horizon gradient and matching ground haze; it is generated at runtime, needs no external texture assets, and keeps the Compatibility renderer path.
- Arena lighting now uses a slightly brighter cool ambient fill, subtle distance haze, and restrained contrast/saturation grading to separate concrete, team colors, and objective accents.
- Thin emissive cyan and amber strips accent the upper perimeter walls; they are unlit mesh effects with shadows disabled and add no collision, navigation, or dynamic-light cost.
- Existing high and low cover blocks now have inset-looking dark face plates with restrained cyan trim; the details are visual-only, cast no shadows, and do not change collision or bot navigation.
- Perimeter walls now include slim dark steel ribs with small cyan edge accents, adding architectural depth while remaining non-colliding, shadow-free, and independent of bot navigation.
- Two edge drainage grates and rear service panels add a restrained industrial floor finish; all parts are mesh-only, cast no shadows, and do not alter collision or navigation.

- Both bomb sites now have four low-cost emissive corner beacons and a matching center marker: cool cyan for Site A and amber for Site B.
- Floating billboarded `SITE A / ALPHA` and `SITE B / BRAVO` labels make both objectives readable from different approach angles; labels use outlined `Label3D` text and add no collision or dynamic lights.
- First-person AR-17/PX-9 viewmodels now emit a brief, unlit emissive muzzle flash on accepted shots; the effect uses a single visual mesh and a short timer, with no particles or extra dynamic lights.
- The dropped/planted bomb has a visible status LED whose blink rate accelerates as the planted timer runs down; the light and LED share the urgency cue, with no particle system or extra dynamic lights.
- Bomb presentation now adds a gentle hover/slow turn while dropped and a restrained, countdown-accelerated scale pulse while planted; the animation is visual-only and adds no physics or particles.
- The beacons are visual-only meshes with shadows disabled; they do not add collision, navigation obstacles, or gameplay effects.

### Network diagnostics

Press `F3` during play to show an opt-in NetGraph overlay. It reports the current offline/server/client mode, sent input commands, received snapshots, acknowledged input sequence, pending predicted commands, rejected inputs, snapshot tick gaps, prediction corrections, latest snapshot tick, rejected snapshot count, malformed bot-roster count, and the most frequent input rejection reasons. The overlay is diagnostic only and does not alter gameplay state.

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


### Contact source handoff
- The squad now keeps its current contact source while that bot remains alive and has line of sight.
- If the contact source is eliminated or loses contact, the director selects a replacement from alive bots with line of sight, preferring the active PRESSURE role, then SUPPORT, then FLANK through a small role-aware distance bias.
- A replacement source changes the contact revision and restarts the Combat Director contact timing window, preventing the squad from inheriting stale fire timing from the previous source.
- If no replacement has line of sight, the existing tactical memory and search/re-engagement pipeline remains responsible for the squad target.


### Squad threat assessment
- The squad now exposes an explicit threat state derived from the existing contact, tactical-memory, and search systems: **CONTACT**, **TRACKED**, **SEARCHING**, or **LOST**.
- CONTACT uses the live observed player position and preserves the existing Combat Director timing.
- TRACKED means the player is no longer directly visible but a fresh shared tactical position is still available; bots can re-engage that position without treating it as live vision.
- SEARCHING means the tactical memory has expired and the squad is actively sweeping the bounded last-known area.
- LOST means the squad has neither a current contact, fresh tactical memory, nor an active search target; bots stop treating the stale position as authoritative and fall back to defense.
- Threat revisions are published through the Combat Director so role-versioned handoffs and stale movement state can react to a meaningful change in threat state.
- Bomb DEFUSE and BOMB_COVER remain higher-priority objective states.


### Threat-based role redistribution
- Squad role assignment now reads the explicit threat state instead of relying only on bot distance and previous roles.
- **CONTACT** keeps the normal PRESSURE / SUPPORT / FLANK structure while favoring a healthy close pressure unit, a stable support unit, and a separated flank.
- **TRACKED** biases PRESSURE toward the tracked threat position, keeps SUPPORT closer to the squad center, and gives FLANK a wider lateral separation for re-engagement.
- **SEARCHING** biases PRESSURE toward the center search lane while SUPPORT and FLANK spread into separate search sectors.
- **LOST** keeps role continuity but removes stale positional aggression through the Combat Director's HOLD command.
- Role persistence is still used as a small tie-breaker, so bots do not swap roles unnecessarily when the tactical scores are close.
- Threat revisions now trigger an immediate role reassessment instead of waiting for the normal assignment interval.


### Threat-aware combat posture
- Bots now treat the squad threat state as an explicit combat-authority layer, not only as a movement hint.
- **CONTACT** is the only threat state that grants normal firing authority; direct line of sight is still required before a shot is taken.
- **TRACKED** allows bounded re-engagement movement but does not authorize firing from stale shared position data.
- **SEARCHING** forces a HOLD combat intent while the dedicated search state controls movement, preventing stale target assumptions from turning into blind attacks.
- **LOST** clears stale aggressive intent and returns bots to defensive behavior until a new contact or objective event changes the threat state.
- A threat revision immediately invalidates stale combat routes and decisions so a bot does not continue an old attack plan after the squad's tactical picture changes.
- Bomb DEFUSE and BOMB_COVER objective priorities remain above the threat posture layer.


### Threat-scaled engagement posture
- Combat intent now scales with the squad threat state and assigned role instead of using one fixed push threshold.
- **CONTACT / PRESSURE** receives the highest aggression budget and can extend its engagement range while healthy.
- **CONTACT / SUPPORT** uses a tighter, health-aware push window so support can reinforce pressure without automatically overcommitting.
- **CONTACT / FLANK** receives a wider lateral engagement window while retaining a stronger health requirement.
- **TRACKED** can reposition toward the tracked threat but remains conservative because stale information does not authorize blind fire.
- **SEARCHING** and **LOST** remain non-aggressive states; the dedicated search/defense logic controls movement.


### Bot fire discipline
- Bot fire now respects the explicit `FIRE_RANGE` limit instead of firing at any target that happens to have a clear raycast.
- Attempts to fire beyond that range cancel the pending burst rather than carrying it into a later engagement.
- The existing threat gate still requires `CONTACT` plus direct line of sight before a shot can be taken.


### Burst discipline
- A bot burst is now cancelled immediately when squad threat is no longer CONTACT, line of sight is lost, or the current state is not a firing state.
- A later re-acquisition therefore starts a fresh burst instead of resuming fire from a stale visual contact.
- This complements the existing threat-revision reset and FIRE_RANGE gate.


### Combat Director cleanup
- The Combat Director threat fallback now has a single TRACKED branch, removing a redundant state path while preserving the existing command behavior.


### Combat Director threat synchronization
- The Combat Director now tracks both contact revisions and threat revisions when deciding whether its cached phase is still current.
- Threat transitions are reflected explicitly as **SEARCH**, **TRACKED**, or **LOST** instead of allowing the director phase to lag behind the squad threat state.
- A meaningful threat revision immediately refreshes the director revision, allowing bots to invalidate stale command timing without waiting for the normal 0.20-second director interval.
- Duplicate threat-role selection code was removed from the main match controller so the squad role allocator has one authoritative implementation.


### Bomb-objective combat role coordination
- The squad role allocator now considers an active **DROPPED** or **PLANTED** bomb before assigning generic combat roles.
- During a dropped-bomb state, the closest suitable bot is preferentially retained as **SUPPORT** near the recovery objective while the remaining squad can continue PRESSURE/FLANK behavior.
- During a planted-bomb state, two suitable bots can be allocated around the objective before the remaining bot receives the normal PRESSURE role.
- Objective-guard selection prefers existing SUPPORT/FLANK continuity and accounts for the current CONTACT/TRACKED threat position, reducing unnecessary movement away from the bomb.
- Existing bot objective states remain authoritative: **DEFUSE** and **BOMB_COVER** still take priority over generic combat posture.


### Bomb-site cover spacing and angle selection
- Bomb-cover selection now reserves both the assigned cover position and the bot's peek/hold goal, reducing duplicate cover and peek lanes.
- Candidate positions receive a spacing penalty when they are too close to another defender's current position or reserved bomb-cover position.
- The selector adds a combat-slot-aware angle bias around the planted site, helping cover bots distribute across different approach directions instead of choosing only the nearest anchor.
- Existing line-of-sight, distance, site-radius, and occupancy checks remain in place; if no valid candidate remains, the bot retains the existing site-position fallback.


### Immediate combat-role refresh on objective changes
- Bot combat assignments now refresh immediately when the bomb objective changes state or planted site, rather than waiting for the periodic assignment interval.
- A dropped-bomb position change of at least 0.5 world units also triggers a refresh, keeping the designated recovery/guard role aligned with a newly dropped objective.
- Contact and threat revision triggers remain unchanged, and the cached objective signature is reset at round start.

### Visual combat feedback
- Player and host shots now render a short-lived, emissive tracer from the firing camera toward the first raycast impact (or a capped distant endpoint).
- Rifle and sidearm tracers use distinct cool/amber tints. The effect is visual-only and uses a tiny temporary mesh rather than particles or dynamic lights.

### Objective-site visual readability
- Site A and Site B use distinct amber/cyan floor-zone tints and matching outlined 3D labels, making the two bomb locations easier to distinguish at a glance.
- Objective markers are render-only, do not cast shadows, and do not change collision, movement, or bot navigation.
