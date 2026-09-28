class_name OpenStrikeCombatEvents
extends Node

signal combat_event(event: OpenStrikeCombatEvent)

var tick: int = 0

func advance_tick() -> int:
	tick += 1
	return tick

func emit_shot(shooter_id: String, weapon_id: String, ammo_left: int, reserve_left: int) -> void:
	combat_event.emit(OpenStrikeCombatEvent.shot(tick, shooter_id, weapon_id, ammo_left, reserve_left))

func emit_hit(shooter_id: String, target_id: String, weapon_id: String, damage: int, hit_position: Vector3, authoritative: bool) -> void:
	combat_event.emit(OpenStrikeCombatEvent.hit(tick, shooter_id, target_id, weapon_id, damage, hit_position, authoritative))

func emit_reload(shooter_id: String, weapon_id: String, ammo_left: int, reserve_left: int) -> void:
	combat_event.emit(OpenStrikeCombatEvent.reload(tick, shooter_id, weapon_id, ammo_left, reserve_left))

func emit_elimination(shooter_id: String, target_id: String, weapon_id: String, authoritative: bool) -> void:
	combat_event.emit(OpenStrikeCombatEvent.elimination(tick, shooter_id, target_id, weapon_id, authoritative))
