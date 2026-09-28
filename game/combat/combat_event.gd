class_name OpenStrikeCombatEvent
extends RefCounted

enum Type {
	SHOT,
	HIT,
	RELOAD,
	ELIMINATION
}

var type: Type
var tick: int = 0
var shooter_id: String = ""
var target_id: String = ""
var weapon_id: String = ""
var damage: int = 0
var ammo: int = 0
var reserve: int = 0
var hit_position := Vector3.ZERO
var authoritative: bool = false

static func shot(tick_value: int, shooter: String, weapon: String, ammo_left: int, reserve_left: int) -> OpenStrikeCombatEvent:
	var event := OpenStrikeCombatEvent.new()
	event.type = Type.SHOT
	event.tick = tick_value
	event.shooter_id = shooter
	event.weapon_id = weapon
	event.ammo = ammo_left
	event.reserve = reserve_left
	return event

static func hit(tick_value: int, shooter: String, target: String, weapon: String, damage_value: int, position: Vector3, is_authoritative: bool) -> OpenStrikeCombatEvent:
	var event := OpenStrikeCombatEvent.new()
	event.type = Type.HIT
	event.tick = tick_value
	event.shooter_id = shooter
	event.target_id = target
	event.weapon_id = weapon
	event.damage = damage_value
	event.hit_position = position
	event.authoritative = is_authoritative
	return event

static func reload(tick_value: int, shooter: String, weapon: String, ammo_left: int, reserve_left: int) -> OpenStrikeCombatEvent:
	var event := OpenStrikeCombatEvent.new()
	event.type = Type.RELOAD
	event.tick = tick_value
	event.shooter_id = shooter
	event.weapon_id = weapon
	event.ammo = ammo_left
	event.reserve = reserve_left
	return event

static func elimination(tick_value: int, shooter: String, target: String, weapon: String, is_authoritative: bool) -> OpenStrikeCombatEvent:
	var event := OpenStrikeCombatEvent.new()
	event.type = Type.ELIMINATION
	event.tick = tick_value
	event.shooter_id = shooter
	event.target_id = target
	event.weapon_id = weapon
	event.authoritative = is_authoritative
	return event
