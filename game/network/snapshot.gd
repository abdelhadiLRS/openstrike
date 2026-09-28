class_name OpenStrikeSnapshot
extends RefCounted

## Authoritative state replicated from the server.
## Keep this payload small and deterministic so it can be sent at a fixed rate.
const SCHEMA_VERSION := 2

var schema_version: int = SCHEMA_VERSION
var tick: int = 0
var peer_id: int = 0
var acknowledged_input_sequence: int = 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var health: int = 100
var dead: bool = false
var crouched: bool = false
var round_state: String = "BUY"
var round_number: int = 1
var round_won: bool = false
var round_outcome_reason: String = ""
var objective_state: String = "CARRIED"
var objective_action: String = ""
var objective_action_peer_id: int = -1
var objective_action_time_left: float = 0.0
var carrier_peer_id: int = 0
var dropped_bomb_position := Vector3.ZERO
var planted_site: String = ""
var bomb_time_left: float = 0.0
var weapon_id: String = ""
var ammo: int = 0
var reserve: int = 0
var credits: int = 1200
var owned_weapons: Array[String] = []
var bot_count: int = 0
var bot_states: Array[Dictionary] = []

func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"tick": tick,
		"peer_id": peer_id,
		"ack": acknowledged_input_sequence,
		"position": position,
		"velocity": velocity,
		"yaw": yaw,
		"pitch": pitch,
		"health": health,
		"dead": dead,
		"crouched": crouched,
		"round_state": round_state,
		"round_number": round_number,
		"round_won": round_won,
		"round_outcome_reason": round_outcome_reason,
		"objective_state": objective_state,
		"objective_action": objective_action,
		"objective_action_peer_id": objective_action_peer_id,
		"objective_action_time_left": objective_action_time_left,
		"carrier_peer_id": carrier_peer_id,
		"dropped_bomb_position": dropped_bomb_position,
		"planted_site": planted_site,
		"bomb_time_left": bomb_time_left,
		"weapon_id": weapon_id,
		"ammo": ammo,
		"reserve": reserve,
		"credits": credits,
		"owned_weapons": owned_weapons,
		"bot_count": bot_count,
		"bot_states": bot_states
	}

static func from_dict(data: Dictionary) -> OpenStrikeSnapshot:
	var snapshot := OpenStrikeSnapshot.new()
	snapshot.schema_version = int(data.get("schema", 0))
	snapshot.tick = int(data.get("tick", 0))
	snapshot.peer_id = int(data.get("peer_id", 0))
	snapshot.acknowledged_input_sequence = int(data.get("ack", 0))
	snapshot.position = data.get("position", Vector3.ZERO)
	snapshot.velocity = data.get("velocity", Vector3.ZERO)
	snapshot.yaw = float(data.get("yaw", 0.0))
	snapshot.pitch = float(data.get("pitch", 0.0))
	snapshot.health = int(data.get("health", 100))
	snapshot.dead = bool(data.get("dead", false))
	snapshot.crouched = bool(data.get("crouched", false))
	snapshot.round_state = str(data.get("round_state", "BUY"))
	snapshot.round_number = int(data.get("round_number", 1))
	snapshot.round_won = bool(data.get("round_won", false))
	snapshot.round_outcome_reason = str(data.get("round_outcome_reason", ""))
	snapshot.objective_state = str(data.get("objective_state", "CARRIED"))
	snapshot.objective_action = str(data.get("objective_action", ""))
	snapshot.objective_action_peer_id = int(data.get("objective_action_peer_id", -1))
	snapshot.objective_action_time_left = float(data.get("objective_action_time_left", 0.0))
	snapshot.carrier_peer_id = int(data.get("carrier_peer_id", 0))
	snapshot.dropped_bomb_position = data.get("dropped_bomb_position", Vector3.ZERO)
	snapshot.planted_site = str(data.get("planted_site", ""))
	snapshot.bomb_time_left = float(data.get("bomb_time_left", 0.0))
	snapshot.weapon_id = str(data.get("weapon_id", ""))
	snapshot.ammo = int(data.get("ammo", 0))
	snapshot.reserve = int(data.get("reserve", 0))
	snapshot.credits = int(data.get("credits", 1200))
	snapshot.bot_count = clampi(int(data.get("bot_count", 0)), 0, 15)
	var bot_value = data.get("bot_states", [])
	if bot_value is Array:
		for bot_state in bot_value:
			if bot_state is Dictionary:
				snapshot.bot_states.append(bot_state)
	var owned_value = data.get("owned_weapons", [])
	if owned_value is Array:
		for weapon_value in owned_value:
			var weapon_name := str(weapon_value)
			if not weapon_name.is_empty() and not snapshot.owned_weapons.has(weapon_name):
				snapshot.owned_weapons.append(weapon_name)
	return snapshot
