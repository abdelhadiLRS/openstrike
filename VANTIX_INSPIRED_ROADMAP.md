# VANTIX-Inspired Systems Roadmap for OpenStrike

This document adapts *systems ideas* observed in [VANTIX](https://github.com/vantixorg/vantix) to OpenStrike's Godot 4 / GDScript codebase. It is a design plan, not a claim that these systems are already implemented.

## Guardrails

- Reimplement concepts in OpenStrike's own architecture; do not copy VANTIX source code, art, sounds, maps, branding, or other assets.
- Keep OpenStrike's original identity and MIT project license. Check the license of any third-party dependency or asset before adding it.
- Prefer small, reviewable changes. Preserve current gameplay and round/objective behavior.
- Do not claim multiplayer fairness or anti-cheat guarantees until server-authoritative behavior is implemented and tested.

## Adaptation map

| VANTIX concept | OpenStrike adaptation | Priority |
|---|---|---|
| Server-authoritative networking | Dedicated authoritative match host owns health, damage, ammo, economy, round state, objective and bot decisions; clients send validated input/actions | P0 |
| Tick-stamped input / 128 Hz simulation | Define a fixed simulation tick and sequence-numbered input packets; start with a modest configurable rate and profile before targeting 128 Hz | P0 |
| Client prediction + reconciliation | Predict only local movement; reconcile against authoritative snapshots with bounded smoothing and replay of unacknowledged inputs | P1 |
| Lag compensation | Maintain a short server-side history of player hitboxes; rewind only for validated shot timestamps within a strict limit | P2 |
| Fog-of-war / information filtering | Send clients only relevant enemy state; never rely on client-side hiding for secrecy | P2 |
| Reconnect grace | Preserve player slot, team, inventory, and round state for a short configurable grace window | P1 |
| Data-driven weapons | Move weapon parameters into typed Godot Resources or validated data files; centralize fire rate, damage, spread, recoil, ammo, reload, and price | P0 |
| Layered/distance-aware audio | Add near/mid/far weapon layers and material-based footsteps after original/licensed audio is available | P2 |
| Bot drop-in replacement | Treat each bot/player as a match slot; transfer slot ownership safely on join/leave without resetting the round | P1 |
| Runtime console / ConVars | Add a permission-gated developer console with typed variables, defaults, ranges, and server/client scopes | P1 |
| NetGraph / performance overlay | Show authoritative network diagnostics in an opt-in debug-only overlay, including input/snapshot flow, pending prediction, rejection reasons, tick gaps, and corrections | P1 (implemented) |
| Visual arena dressing | Build an original industrial look with lightweight procedural details while preserving gameplay geometry; current graybox dressing is implemented, but final authored materials, textures, and character assets remain future work | P1 (procedural pass implemented) |
| Art-quality progression | Replace placeholder graybox surfaces in stages with original modular environment meshes, restrained PBR materials, and optimized texture atlases; preserve a LOW profile for integrated GPUs and keep collision/navigation meshes separate | P2 (procedural floor and perimeter-wall material pass implemented; authored assets/atlases remain planned) |
| Authoritative bot roster snapshots | Replicate an explicit bot count, synchronize client bot slots without per-snapshot cache rebuilds, and reject inconsistent count/state payloads | P1 (implemented) |
| Smoke, penetration, per-limb damage | Add as separate gameplay systems only after authoritative hitscan, collision/material rules, and tests are stable | P2 |
| Dedicated server and launch flags | Add headless server, listen-server, connect-address, port, and bot-count options with clear startup validation | P1 (listen-server/launch flags implemented; headless remains) |

## Visual production backlog

The current arena has a coherent procedural industrial look, but it is still a graybox-style prototype. The next visual milestone is to replace placeholder shapes in controlled stages—not to add more decorative meshes indiscriminately.

### Visual pass V1 — Material and lighting consistency
1. Audit the floor, perimeter walls, cover, metal props, and objective surfaces for roughness/metallic consistency and excessive emissive accents.
2. Create a small set of reusable original material profiles: concrete, painted metal, dark rubber, hazard paint, and emissive signage. Keep shader complexity low and preserve the existing LOW/BALANCED/HIGH profiles.
3. Improve material scale and surface variation without adding unique materials per prop; use shared materials and restrained tiling.
4. Check readability from player eye height: enemy silhouettes, cover edges, bomb sites, and muzzle/impact effects must remain distinct under all quality profiles.

### Visual pass V2 — Modular environment art
1. Replace the most prominent flat wall and cover blocks with a small modular kit: wall panels, corner pieces, door frames, support columns, crates, and cover variants.
2. Keep render meshes separate from simplified collision/navigation geometry so visual detail cannot create invisible gameplay blockers.
3. Use original meshes and textures or assets with compatible licenses; do not import another game's map, models, or branding.
4. Prioritize the central lane and both bomb sites first, then expand to the perimeter after the new pieces are validated in the live map.

### Visual pass V3 — Character and weapon art
1. Replace procedural box/capsule character details with a small original low-poly character mesh and a compact skeleton/animation set.
2. Keep the existing capsule hitbox independent from the render rig; validate crouch, death, respawn, and network interpolation with the new rig.
3. Replace the geometric AR-17/PX-9 viewmodels with original low-poly models, keeping muzzle positions and sight alignment consistent with the current camera-centered hit registration.
4. Add original animation/audio only after the rig and weapon transforms are stable.

### Performance and acceptance gates
- Keep a low-spec path suitable for integrated graphics: no mandatory high-resolution textures, expensive real-time lights, or dense particle effects.
- Prefer shared materials, limited texture atlases, shadow-free small props, and a small number of shadow-casting lights.
- Compare HIGH, BALANCED, and LOW at the same map locations and during sustained combat; record frame time and memory before increasing visual complexity.
- Each asset pass must preserve movement, collision, bot navigation, weapon alignment, and authoritative multiplayer state. Treat screenshots and an in-engine smoke test as required review artifacts before calling the art pass complete.

## Delivery sequence

### Phase 0 — Stability and boundaries
1. Keep the current round-state lifecycle as the source of truth and ensure bots stop acting outside LIVE play.
2. Add small automated checks for round transitions, team/slot accounting, weapon reload, and objective completion.
3. Document the current single-player prototype boundary and the intended multiplayer authority model.

### Phase 1 — Gameplay foundations
1. Introduce weapon definitions as data, with validation for positive fire interval, magazine size, reserve ammo, damage, and cost.
2. Centralize combat events (shot, hit, elimination, reload) so HUD, audio, score, and later networking consume the same event.
3. Make player and bot slot ownership explicit; test bot-to-player handoff and disconnect recovery.

### Phase 2 — Multiplayer foundation
1. Define a versioned input/action packet and authoritative snapshot schema; the authoritative snapshot schema is now versioned and incompatible schemas are rejected before state application. Bot roster snapshots carry an explicit count, require a contiguous 1..N bot ID set, and are rejected before client roster mutation when malformed. Owned-weapon inventory is also validated for string IDs, uniqueness, and bounded length before applying snapshots.
2. Move all match-critical mutations to the server; validate team, phase, distance, cooldown, ammo, and ownership server-side.
3. Add sequence numbers, bounded packet sizes, timeouts, and reconnect grace; test invalid and delayed packets.
4. Add local prediction/reconciliation only after the authoritative loop is stable.

### Phase 3 — Competitive fidelity
1. Add bounded lag-compensation history and deterministic shot evaluation.
2. Add information filtering, objective-aware smoke, material penetration rules, and spatialized audio as isolated systems.
3. Profile with bots and real network conditions; tune tick rate only from measured results.

## Acceptance checklist

- BUY and POST phases cannot process combat, movement orders, or objective actions for bots.
- Only the authoritative host can confirm damage, credits, kills, planting/defusing, and round results.
- Invalid, stale, duplicate, or out-of-phase actions are rejected safely.
- Reconnecting players recover the intended slot state without duplicating inventory or rewards.
- Debug metrics are opt-in and do not affect release gameplay.
- Each phase has automated checks and a Godot runtime smoke test before merging.

## Source

- VANTIX repository and public project overview: https://github.com/vantixorg/vantix
- This document summarizes high-level engineering concepts; it does not reproduce VANTIX implementation code or proprietary assets.
