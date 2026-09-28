@tool
class_name OpenStrikeWeaponDefinition
extends Resource

@export var weapon_id: StringName
@export var display_name: String = ""
@export var magazine_size: int = 1
@export var reserve_ammo: int = 0
@export var damage: int = 1
@export var fire_interval: float = 0.1
@export var recoil: float = 0.0
@export var cost: int = 0
@export var movement_speed: float = 5.0

func is_valid() -> bool:
	return (
		not weapon_id.is_empty()
		and not display_name.is_empty()
		and magazine_size > 0
		and reserve_ammo >= 0
		and damage > 0
		and is_finite(fire_interval)
		and fire_interval > 0.0
		and is_finite(recoil)
		and recoil >= 0.0
		and cost >= 0
		and is_finite(movement_speed)
		and movement_speed > 0.0
	)

func to_runtime_dict() -> Dictionary:
	return {
		"id": String(weapon_id),
		"name": display_name,
		"mag": magazine_size,
		"reserve": reserve_ammo,
		"damage": damage,
		"delay": fire_interval,
		"recoil": recoil,
		"cost": cost,
		"speed": movement_speed
	}
