class_name OpenStrikeWeaponRuntimeState
extends RefCounted

var weapon_id: StringName
var magazine_size: int
var ammo: int
var reserve_ammo: int
var owned: bool = false
var cooldown_remaining: float = 0.0

static func from_definition(definition: Dictionary, initially_owned: bool = false) -> OpenStrikeWeaponRuntimeState:
	var state := OpenStrikeWeaponRuntimeState.new()
	state.weapon_id = StringName(str(definition.get("id", "")))
	state.magazine_size = maxi(1, int(definition.get("mag", 1)))
	state.ammo = state.magazine_size
	state.reserve_ammo = maxi(0, int(definition.get("reserve", 0)))
	state.owned = initially_owned
	return state

func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(delta, 0.0))

func can_fire() -> bool:
	return owned and cooldown_remaining <= 0.0001 and ammo > 0

func consume_shot(fire_interval: float) -> bool:
	if not can_fire():
		return false
	ammo -= 1
	cooldown_remaining = maxf(0.0, fire_interval)
	return true

func reload() -> int:
	var needed := maxi(0, magazine_size - ammo)
	var loaded := mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	return loaded

func set_loaded_state(loaded_ammo: int, reserve: int) -> void:
	ammo = clampi(loaded_ammo, 0, magazine_size)
	reserve_ammo = maxi(0, reserve)

func snapshot() -> Dictionary:
	return {
		"weapon_id": String(weapon_id),
		"ammo": ammo,
		"reserve": reserve_ammo,
		"owned": owned,
		"cooldown": cooldown_remaining
	}
