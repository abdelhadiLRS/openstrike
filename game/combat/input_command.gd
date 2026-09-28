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

func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"tick": tick,
		"move": move,
		"look_delta": look_delta,
		"fire": fire,
		"reload": reload,
		"crouch": crouch,
		"jump": jump
	}
