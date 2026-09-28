# OpenStrike external systems integration

OpenStrike uses external projects as architectural references and optional implementation targets, not as a source-code or asset copy.

## Sources reviewed

- VANTIX: server authority, client prediction, lag compensation, sub-tick input, tactical FPS structure.
- ETA: 128 Hz simulation ideas, prediction/reconciliation, rewind buffers, material-aware weapon/audio effects.
- DADABOOM: authoritative fire resolution, snapshot interpolation, bot filling, persistence and room-oriented multiplayer.
- netfox CS sample: rollback-oriented FPS architecture, authoritative bomb/economy/weapons and latency-compensated hitscan.
- Godot networking documentation: high-level multiplayer, RPC, replication and ENet/UDP considerations.

## Adaptation rule

OpenStrike remains GDScript-first and keeps its existing gameplay systems. We implement the useful concepts as small internal modules so the project does not become dependent on unrelated codebases.

## Current integration layer

- `OpenStrikeWeaponRuntimeState`: separates mutable magazine/reserve/ownership/cooldown state from static weapon Resources.
- `OpenStrikeCombatValidator`: centralizes fire/reload acceptance rules and explicit rejection reasons.
- `OpenStrikeCombatEvents`: normalized combat events remain the bridge between local gameplay and future authoritative server resolution.

## Next integration stages

1. Route player fire/reload through the validator and runtime state.
2. Add fixed simulation ticks and input sequence numbers.
3. Add snapshot history and client reconciliation.
4. Add rewind-based lag compensation for hitscan.
5. Add server-owned round/economy/objective state.
6. Add network diagnostics and dedicated-server launch mode.

Do not copy external source code or proprietary assets into OpenStrike. Re-implement behavior from documented concepts under OpenStrike's own architecture and licensing.
