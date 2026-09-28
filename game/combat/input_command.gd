class_name OpenStrikeInputCommand
extends RefCounted

var sequence: int = 0
var tick: int = 0
var move: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var fire: bool = false
var reload: bool = false
var crouch: bool = false
var jump: bool = false
var objective: bool = false
var weapon_id: String = "px_9"
var buy_weapon_id: String = ""
var switch_weapon: bool = false

func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"tick": tick,
		"move": move,
		"look_delta": look_delta,
		"fire": fire,
		"reload": reload,
		"crouch": crouch,
		"jump": jump,
		"objective": objective,
		"weapon_id": weapon_id,
		"buy_weapon_id": buy_weapon_id,
		"switch_weapon": switch_weapon
	}

func from_dict(payload: Dictionary) -> OpenStrikeInputCommand:
	var command := OpenStrikeInputCommand.new()
	if payload == null:
		return command
	command.sequence = int(payload.get("sequence", 0))
	command.tick = int(payload.get("tick", 0))
	command.weapon_id = str(payload.get("weapon_id", "px_9"))
	command.buy_weapon_id = str(payload.get("buy_weapon_id", ""))
	command.switch_weapon = bool(payload.get("switch_weapon", false))
	var move_value = payload.get("move", Vector2.ZERO)
	var look_value = payload.get("look_delta", Vector2.ZERO)
	command.move = move_value if move_value is Vector2 else Vector2.ZERO
	command.look_delta = look_value if look_value is Vector2 else Vector2.ZERO
	command.fire = bool(payload.get("fire", false))
	command.reload = bool(payload.get("reload", false))
	command.crouch = bool(payload.get("crouch", false))
	command.jump = bool(payload.get("jump", false))
	command.objective = bool(payload.get("objective", false))
	return command
