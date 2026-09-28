class_name OpenStrikeCombatEvents
extends Node

signal combat_event(event: OpenStrikeCombatEvent)

const MAX_HISTORY := 128

var tick: int = 0
var validator := OpenStrikeCombatValidator.new()
var history: Array[OpenStrikeCombatEvent] = []

func advance_tick() -> int:
	tick += 1
	return tick

func record(event: OpenStrikeCombatEvent) -> void:
	history.push_back(event)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	combat_event.emit(event)

func recent_events() -> Array[OpenStrikeCombatEvent]:
	return history.duplicate()

func validate_fire(
	round_state: String,
	is_dead: bool,
	weapon: Dictionary,
	weapon_owned: bool,
	cooldown: float,
	ammo: int,
	target: Node = null,
	shooter_team: String = ""
) -> OpenStrikeCombatValidator.Result:
	return OpenStrikeCombatValidator.validate_fire(
		round_state,
		is_dead,
		weapon,
		weapon_owned,
		cooldown,
		ammo,
		target,
		shooter_team,
		int(weapon.get("damage", 0))
	)

func validate_reload(round_state: String, is_dead: bool, weapon: Dictionary, ammo: int, reserve: int) -> OpenStrikeCombatValidator.Result:
	return OpenStrikeCombatValidator.validate_reload(round_state, is_dead, weapon, ammo, reserve)

func emit_shot(shooter_id: String, weapon_id: String, ammo_left: int, reserve_left: int) -> void:
	record(OpenStrikeCombatEvent.shot(tick, shooter_id, weapon_id, ammo_left, reserve_left))

func emit_hit(shooter_id: String, target_id: String, weapon_id: String, damage: int, hit_position: Vector3, authoritative: bool) -> void:
	record(OpenStrikeCombatEvent.hit(tick, shooter_id, target_id, weapon_id, damage, hit_position, authoritative))

func emit_reload(shooter_id: String, weapon_id: String, ammo_left: int, reserve_left: int) -> void:
	record(OpenStrikeCombatEvent.reload(tick, shooter_id, weapon_id, ammo_left, reserve_left))

func emit_elimination(shooter_id: String, target_id: String, weapon_id: String, authoritative: bool) -> void:
	record(OpenStrikeCombatEvent.elimination(tick, shooter_id, target_id, weapon_id, authoritative))
