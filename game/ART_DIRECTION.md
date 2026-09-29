# OpenStrike — Art Direction & Visual Production Plan

## Visual identity

OpenStrike is an original, compact tactical FPS set in a near-future industrial training complex. Its visual language is **readable tactical industrialism**: cool graphite concrete and dark painted steel, restrained cyan for BLUE/allied navigation, amber for RED/objective warnings, and red reserved for critical danger. Avoid copying proprietary maps, logos, weapon silhouettes, UI layouts, or assets from other games.

## Art pillars

1. **Combat readability first** — players, cover edges, muzzle flashes, objective sites, and incoming-damage cues must remain distinguishable at typical gameplay distance.
2. **One coherent material family** — concrete, coated steel, rubber, glass, and emissive signage should share consistent roughness and value ranges.
3. **Silhouette before surface detail** — prioritize distinct player/weapon profiles and recognizable cover shapes before adding small decals.
4. **Lightweight by design** — use shared materials, low-poly meshes, baked/static-looking emissive details, and capped transient effects. Avoid adding per-prop dynamic lights or expensive particle systems.
5. **Gameplay geometry stays authoritative** — decorative meshes must not change collision, hitboxes, navigation, line-of-sight, or network state.

## Current presentation baseline

The current graybox already has procedural concrete and wall materials, industrial signage/fixtures, objective-site stencils and beacons, low-poly combatant silhouettes, first-person weapon viewmodels, impact/tracer feedback, HUD/minimap, and HIGH/BALANCED/LOW plus reduced-motion options. These are a procedural presentation layer, not a finished authored environment.

## Next production passes

### Pass 1 — Coherent modular environment kit
- Replace repeated plain blockout silhouettes with a small kit: wall segments, reinforced corners, doors/frames, waist-high cover, crates, and service panels.
- Reuse a small set of shared materials and dimensions; preserve the existing collision volumes and bot navigation graph.
- Acceptance: no new gameplay collision from decorative trim; all combat lanes and both objective sites remain readable; LOW profile remains usable on integrated graphics.

### Pass 2 — Material and wear language
- Establish shared material presets for concrete, painted metal, rubber, and warning paint.
- Add restrained edge wear and surface variation only where it helps scale and object identity; avoid noisy high-frequency detail.
- Acceptance: floor markings remain legible, visual noise does not obscure targets, and no large texture memory dependency is introduced.

### Pass 3 — Character and weapon silhouette refinement
- Normalize proportions across BLUE and RED avatars, improve team-color placement, and distinguish rifle/sidearm silhouettes from first-person and third-person views.
- Keep decorative armor and viewmodel parts separate from collision and authoritative hit registration.
- Acceptance: team identity and weapon class are recognizable at a glance; no change to hitboxes or weapon behavior.

### Pass 4 — Second compact arena
- Build a distinct layout using the same kit, not a recolor of the current arena.
- Validate spawn separation, sightlines, cover spacing, objective approach routes, and bot navigation before adding decorative density.
- Acceptance: both sites are reachable and defensible, bots do not get stuck in core routes, and network snapshots remain independent of decorative nodes.

## Quality profiles

- **HIGH:** full presentation effects and 4x MSAA.
- **BALANCED:** reduced post-processing and 2x MSAA.
- **LOW:** disable costly atmospheric and antialiasing features.
- **Reduced motion:** suppress continuous camera/viewmodel motion and comfort-sensitive impulses.

Every new visual feature must state whether it is mesh-only, whether it casts shadows, whether it allocates transient nodes, and how it behaves in LOW/reduced-motion modes. Do not claim visual or performance acceptance until tested in Godot on target hardware.
