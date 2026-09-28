class_name OpenStrikeSnapshot
extends RefCounted

## Authoritative state replicated from the server.
## Keep this payload small and deterministic so it can be sent at a fixed rate.
var tick: int = 0
var acknowledged_input_sequence: int = 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var health: int = 100
var dead: bool = false
var round_state: String = "BUY"
var round_number: int = 1
var objective_state: String = "CARRIED"
var planted_site: String = ""
var bomb_time_left: float = 0.0
var weapon_id: String = ""
var ammo: int = 0
var reserve: int = 0

func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"ack": acknowledged_input_sequence,
		"position": position,
		"velocity": velocity,
		"yaw": yaw,
		"pitch": pitch,
		"health": health,
		"dead": dead,
		"round_state": round_state,
		"round_number": round_number,
		"objective_state": objective_state,
		"planted_site": planted_site,
		"bomb_time_left": bomb_time_left,
		"weapon_id": weapon_id,
		"ammo": ammo,
		"reserve": reserve
	}

static func from_dict(data: Dictionary) -> OpenStrikeSnapshot:
	var snapshot := OpenStrikeSnapshot.new()
	snapshot.tick = int(data.get("tick", 0))
	snapshot.acknowledged_input_sequence = int(data.get("ack", 0))
	snapshot.position = data.get("position", Vector3.ZERO)
	snapshot.velocity = data.get("velocity", Vector3.ZERO)
	snapshot.yaw = float(data.get("yaw", 0.0))
	snapshot.pitch = float(data.get("pitch", 0.0))
	snapshot.health = int(data.get("health", 100))
	snapshot.dead = bool(data.get("dead", false))
	snapshot.round_state = str(data.get("round_state", "BUY"))
	snapshot.round_number = int(data.get("round_number", 1))
	snapshot.objective_state = str(data.get("objective_state", "CARRIED"))
	snapshot.planted_site = str(data.get("planted_site", ""))
	snapshot.bomb_time_left = float(data.get("bomb_time_left", 0.0))
	snapshot.weapon_id = str(data.get("weapon_id", ""))
	snapshot.ammo = int(data.get("ammo", 0))
	snapshot.reserve = int(data.get("reserve", 0))
	return snapshot
