class_name OpenStrikeCombatAuthority
extends Node

signal shot_accepted(event: OpenStrikeCombatEvent)
signal shot_rejected(reason: OpenStrikeCombatValidator.RejectReason)

var input_sequence: int = 0
var last_processed_sequence: int = 0
var events: OpenStrikeCombatEvents

func setup(combat_event_stream: OpenStrikeCombatEvents) -> void:
	events = combat_event_stream

func next_input_sequence() -> int:
	input_sequence += 1
	return input_sequence

func accept_fire(
	round_state: String,
	is_dead: bool,
	weapon: Dictionary,
	weapon_owned: bool,
	cooldown: float,
	ammo: int,
	shooter_team: String
) -> OpenStrikeCombatValidator.Result:
	if events == null:
		var failed := OpenStrikeCombatValidator.Result.new(false, OpenStrikeCombatValidator.RejectReason.WEAPON_INVALID, "Combat event stream is not initialized.")
		shot_rejected.emit(failed.reason)
		return failed

	var result := events.validate_fire(
		round_state,
		is_dead,
		weapon,
		weapon_owned,
		cooldown,
		ammo,
		null,
		shooter_team
	)
	if not result.accepted:
		shot_rejected.emit(result.reason)
		return result

	events.advance_tick()
	events.emit_shot("player", str(weapon["id"]), ammo - 1, 0)
	last_processed_sequence = input_sequence
	return result
