class_name OpenStrikeNetworkSession
extends Node

## Lightweight Godot-native networking boundary.
## Gameplay remains usable offline; this layer becomes active only when a host/client is started.

signal connected
signal disconnected
signal connection_failed
signal input_received(command: OpenStrikeInputCommand)
signal peer_input_received(peer_id: int, command: OpenStrikeInputCommand)
signal snapshot_received(snapshot: OpenStrikeSnapshot)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal input_rejected(peer_id: int, command: OpenStrikeInputCommand)
signal input_rejected_reason(peer_id: int, command: OpenStrikeInputCommand, reason: String)

var server_input_buffer := OpenStrikeServerInputBuffer.new()
var server_tick := 0


const DEFAULT_PORT := 27015
const MAX_CLIENTS := 16
const KILL_REWARD := 300
const ROUND_WIN_REWARD := 2200
const ROUND_LOSS_REWARD := 1200
const INPUT_CHANNEL := 0
const SNAPSHOT_CHANNEL := 1
const MAX_INPUTS_PER_PEER_TICK := 2
const SNAPSHOT_SCHEMA_VERSION := OpenStrikeSnapshot.SCHEMA_VERSION

var peer: ENetMultiplayerPeer
var is_server := false
var is_online := false
var local_input_sequence := 0
var last_server_sequence := 0
var network_players: Dictionary = {}
var snapshot_interval := 0.05
var snapshot_accumulator := 0.0
var observed_round_number := 0
var observed_round_state := ""
var network_bot_cache: Dictionary = {}
var last_received_snapshot_tick_by_peer: Dictionary = {}
var last_received_snapshot_round_by_peer: Dictionary = {}
var _last_received_bot_count: int = -1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_configure_from_command_line()

func _configure_from_command_line() -> void:
	# Optional launch-time networking keeps the default game offline while
	# allowing repeatable authoritative-host/LAN smoke-test commands.
	var args := OS.get_cmdline_user_args()
	var launch_server := false
	var connect_address := ""
	var launch_port := DEFAULT_PORT
	var max_clients := MAX_CLIENTS
	var show_help := false

	for arg_value in args:
		var arg := str(arg_value).strip_edges()
		if arg == "--server":
			launch_server = true
		elif arg == "--help" or arg == "-h":
			show_help = true
		elif arg.begins_with("--connect="):
			connect_address = arg.trim_prefix("--connect=").strip_edges()
		elif arg.begins_with("--port="):
			launch_port = clampi(int(arg.trim_prefix("--port=")), 1, 65535)
		elif arg.begins_with("--max-clients="):
			max_clients = clampi(int(arg.trim_prefix("--max-clients=")), 1, MAX_CLIENTS)

	if show_help:
		print("OpenStrike network flags: --server | --connect=<address> | --port=<1..65535> | --max-clients=<1..16> | --bots=<0..15>")
		return
	if launch_server and not connect_address.is_empty():
		push_error("OpenStrike: --server and --connect cannot be used together.")
		return
	if not launch_server and not connect_address.is_empty():
		connect_to_server(connect_address, launch_port)
	elif launch_server:
		host(launch_port, max_clients)

func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	_shutdown_peer()
	_reset_snapshot_receive_state()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		peer = null
		is_online = false
		is_server = false
		connection_failed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_online = true
	connected.emit()
	return OK

func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
	_shutdown_peer()
	_reset_snapshot_receive_state()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		peer = null
		is_online = false
		is_server = false
		connection_failed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_online = false
	return OK

func shutdown() -> void:
	_shutdown_peer()
	is_online = false
	is_server = false
	disconnected.emit()

func _on_connected_to_server() -> void:
	if is_server:
		return
	is_online = true
	_reset_snapshot_receive_state()
	connected.emit()

func _on_connection_failed() -> void:
	_clear_session_state()
	is_online = false
	is_server = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	_clear_session_state()
	is_online = false
	is_server = false
	disconnected.emit()

func _on_peer_connected(peer_id: int) -> void:
	if is_server and peer_id > 0:
		peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id > 0:
		server_input_buffer.clear_peer(peer_id)
		last_received_snapshot_tick_by_peer.erase(peer_id)
		last_received_snapshot_round_by_peer.erase(peer_id)
		var root := _root()
		if root != null and root.has_method("set_network_objective_input"):
			root.set_network_objective_input(peer_id, false)
		if root != null and root.has_method("on_network_player_disconnected"):
			root.on_network_player_disconnected(peer_id)
		_remove_network_player(peer_id)
		peer_disconnected.emit(peer_id)

func _physics_process(delta: float) -> void:
	if not is_server or not is_online:
		return
	_sync_round_lifecycle()
	_snapshot_server_players(delta)

func _sync_round_lifecycle() -> void:
	var root := _root()
	if root == null:
		return
	var current_round := int(root.get("round_number"))
	var current_state := str(root.get("round_state"))
	if observed_round_number == 0:
		observed_round_number = current_round
		observed_round_state = current_state
		return
	if current_state == "POST" and observed_round_state != "POST":
		var won := bool(root.get("round_won"))
		var reward := ROUND_WIN_REWARD if won else ROUND_LOSS_REWARD
		for peer_value in network_players.keys():
			var player: OpenStrikeNetworkPlayer = network_players.get(peer_value)
			if is_instance_valid(player):
				player.credits = mini(OpenStrikeNetworkPlayer.MAX_CREDITS, player.credits + reward)
	if current_round != observed_round_number:
		for peer_value in network_players.keys():
			var player: OpenStrikeNetworkPlayer = network_players.get(peer_value)
			if is_instance_valid(player):
				player.begin_round(_spawn_position_for_peer(int(peer_value)))
		observed_round_number = current_round
		observed_round_state = current_state
	elif current_state != observed_round_state:
		observed_round_state = current_state

func _spawn_position_for_peer(peer_id: int) -> Vector3:
	var root := _root()
	if root == null:
		return Vector3.ZERO
	var spawn_points: Array = root.get("blue_spawn_points") if root.get("blue_spawn_points") is Array else []
	if spawn_points.is_empty():
		return Vector3.ZERO
	return spawn_points[(peer_id - 1) % spawn_points.size()]

func _root() -> Node:
	return get_parent()

func _spawn_network_player(peer_id: int) -> OpenStrikeNetworkPlayer:
	if peer_id <= 0:
		return null
	var existing: OpenStrikeNetworkPlayer = network_players.get(peer_id)
	if is_instance_valid(existing):
		return existing
	var root := _root()
	if root == null:
		return null
	var player := OpenStrikeNetworkPlayer.new()
	var spawn := _spawn_position_for_peer(peer_id)
	player.setup(peer_id, spawn, root.get("weapons") if root.get("weapons") is Array else [])
	root.add_child(player)
	network_players[peer_id] = player
	return player

func _remove_network_player(peer_id: int) -> void:
	var player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
	if is_instance_valid(player):
		player.queue_free()
	network_players.erase(peer_id)

func _process_server_input(peer_id: int) -> void:
	var player := _spawn_network_player(peer_id)
	if player == null:
		return
	var root := _root()
	var round_state := str(root.get("round_state")) if root != null else "BUY"

	# Allow a small bounded catch-up when packets arrive in a burst. A command
	# represents one client physics step, so always simulate it with the fixed
	# server step instead of the current frame delta. This keeps movement,
	# gravity and weapon cooldowns deterministic when the server frame stalls.
	var input_step := 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second))
	for _i in MAX_INPUTS_PER_PEER_TICK:
		var command := server_input_buffer.pop_next(peer_id)
		if command == null:
			break
		player.apply_input(command, input_step, round_state)
		if root != null and root.has_method("set_network_objective_input"):
			root.set_network_objective_input(peer_id, command.objective)
		if command.fire and round_state == "LIVE":
			_process_server_fire(player, command)

func _validate_network_command(command: OpenStrikeInputCommand, round_state: String) -> String:
	if command == null:
		return "invalid_command"
	# Match-critical actions are phase-gated on the server. Movement/look can
	# remain valid outside LIVE so prediction does not need a separate protocol.
	if round_state == "BUY":
		if command.fire:
			return "fire_not_allowed_in_buy"
		if command.reload:
			return "reload_not_allowed_in_buy"
		if command.objective:
			return "objective_not_allowed_in_buy"
	elif round_state == "LIVE":
		if command.buy_weapon_id != "":
			return "buy_not_allowed_in_live"
	else:
		if command.fire:
			return "fire_not_allowed_in_round_end"
		if command.reload:
			return "reload_not_allowed_in_round_end"
		if command.objective:
			return "objective_not_allowed_in_round_end"
		if command.buy_weapon_id != "":
			return "buy_not_allowed_in_round_end"
		if command.switch_weapon:
			return "switch_not_allowed_in_round_end"
	# Reject contradictory weapon intents before they reach the authoritative
	# player state. A buy request may select the purchased weapon, or a switch
	# may request the alternate owned weapon, but never both semantics at once.
	if command.buy_weapon_id != "":
		if command.switch_weapon:
			return "buy_and_switch_conflict"
		if command.weapon_id != "" and command.weapon_id != command.buy_weapon_id:
			return "buy_weapon_mismatch"
		if _weapon_definition(command.buy_weapon_id).is_empty():
			return "unknown_buy_weapon"
	elif command.switch_weapon and command.weapon_id != "":
		return "switch_weapon_conflict"
	if command.weapon_id != "" and _weapon_definition(command.weapon_id).is_empty():
		return "unknown_weapon"
	return ""

func _weapon_definition(weapon_id: String) -> Dictionary:
	var root := _root()
	if root == null:
		return {}
	var catalog = root.get("weapons")
	if not catalog is Array:
		return {}
	for weapon in catalog:
		if weapon is Dictionary and str(weapon.get("id", "")) == weapon_id:
			return weapon
	return {}

func _point_to_ray_distance(point: Vector3, origin: Vector3, direction: Vector3) -> float:
	var offset := point - origin
	var along := offset.dot(direction)
	if along < 0.0 or along > 120.0:
		return INF
	return (offset - direction * along).length()

func _process_server_fire(shooter: OpenStrikeNetworkPlayer, command: OpenStrikeInputCommand) -> void:
	if shooter == null or shooter.dead or not command.fire:
		return
	var root := _root()
	if root == null or str(root.get("round_state")) != "LIVE":
		return
	var weapon := _weapon_definition(shooter.weapon_id)
	if weapon.is_empty():
		return
	var delay := float(weapon.get("delay", 0.1))
	var damage := int(weapon.get("damage", 0))
	if delay <= 0.0 or damage <= 0:
		return
	if not shooter.can_fire():
		return
	if not shooter.consume_shot(delay):
		return
	var origin := shooter.global_position + Vector3(0, 0.55, 0)
	var yaw_basis := Basis(Vector3.UP, shooter.yaw)
	var direction := (yaw_basis * Vector3(0, 0, -1)).normalized()
	var pitch_basis := Basis(Vector3.RIGHT, shooter.pitch)
	direction = (yaw_basis * pitch_basis * Vector3(0, 0, -1)).normalized()

	var best_target: Node = null
	var best_distance := INF
	var requested_tick := OpenStrikeLagCompensation.clamp_requested_tick(command.tick, server_tick, OpenStrikeServerInputBuffer.MAX_REWIND_TICKS)

	for peer_value in network_players.keys():
		var target: OpenStrikeNetworkPlayer = network_players.get(peer_value)
		if not is_instance_valid(target) or target == shooter or target.dead:
			continue
		# Friendly players must never become the selected historical hit candidate;
		# otherwise they can incorrectly block an enemy behind them.
		if target.team == shooter.team:
			continue
		var historical_snapshot := OpenStrikeLagCompensation.rewind_snapshot(target.snapshot_history, requested_tick)
		if historical_snapshot == null:
			continue
		var historical := historical_snapshot.position + Vector3(0, 0.65, 0)
		var ray_distance := _point_to_ray_distance(historical, origin, direction)
		if ray_distance <= 0.75 and ray_distance < best_distance:
			best_distance = ray_distance
			best_target = target

	if best_target == null:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
		query.exclude = [shooter]
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != null:
			best_target = hit.collider
			best_distance = origin.distance_to(hit.position)

	var events: OpenStrikeCombatEvents = root.get("combat_events")
	if events != null:
		events.emit_shot(str(shooter.peer_id), shooter.weapon_id, shooter.ammo, shooter.reserve)

	if best_target == null:
		return
	var target_team := str(best_target.get("team"))
	if best_target is OpenStrikeNetworkPlayer:
		var target: OpenStrikeNetworkPlayer = best_target
		if target.dead or target.team == shooter.team:
			return
		var was_alive := not target.dead
		target.health = maxi(0, target.health - damage)
		if target.health <= 0:
			target.mark_eliminated()
			if root.has_method("on_network_player_eliminated"):
				root.on_network_player_eliminated(target.peer_id)
		if events != null:
			events.emit_hit(str(shooter.peer_id), str(target.peer_id), shooter.weapon_id, damage, target.global_position, true)
		if was_alive and target.dead:
			if events != null:
				events.emit_elimination(str(shooter.peer_id), str(target.peer_id), shooter.weapon_id, true)
	elif root.has_method("apply_authoritative_network_damage") and best_target == root.get("player"):
		var was_alive := not bool(root.get("dead"))
		if root.apply_authoritative_network_damage(damage):
			if events != null:
				events.emit_hit(str(shooter.peer_id), "host", shooter.weapon_id, damage, root.get("player").global_position, true)
			if was_alive and bool(root.get("dead")):
				if events != null:
					events.emit_elimination(str(shooter.peer_id), "host", shooter.weapon_id, true)
	elif best_target.has_method("take_damage") and target_team != "BLUE":
		best_target.take_damage(damage, str(shooter.peer_id))
		if events != null:
			events.emit_hit(str(shooter.peer_id), str(best_target.get_instance_id()), shooter.weapon_id, damage, best_target.global_position, true)


func process_host_fire(origin: Vector3, direction: Vector3, weapon_id_value: String, damage: int) -> bool:
    if not is_server or not is_online:
        return false
    var root := _root()
    if root == null or str(root.get("round_state")) != "LIVE":
        return false
    var shooter = root.get("player")
    if shooter == null:
        return false

    # Resolve combat values from the authoritative catalog instead of trusting
    # the caller's damage value. The host has already passed local input
    # validation, but this boundary remains authoritative by design.
    var weapon := _weapon_definition(weapon_id_value)
    if weapon.is_empty():
        return false
    var authoritative_damage := int(weapon.get("damage", 0))
    if authoritative_damage <= 0:
        return false
    damage = authoritative_damage

    var best_target: Node = null
    var best_distance := INF
    var normalized_direction := direction.normalized()

    for peer_value in network_players.keys():
        var target: OpenStrikeNetworkPlayer = network_players.get(peer_value)
        if not is_instance_valid(target) or target.dead:
            continue
        # Do not let a friendly network player win the candidate selection and
        # incorrectly block a hostile target farther along the shot line.
        if target.team == str(root.get("player_team")):
            continue
        var target_position := target.global_position + Vector3(0, 0.65, 0)
        var ray_distance := _point_to_ray_distance(target_position, origin, normalized_direction)
        if ray_distance <= 0.75 and ray_distance < best_distance:
            best_distance = ray_distance
            best_target = target

    if best_target == null:
        var query := PhysicsRayQueryParameters3D.create(origin, origin + normalized_direction * 120.0)
        query.exclude = [shooter]
        var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty() and hit.collider != null:
            best_target = hit.collider

    if best_target == null:
        return false

    var events: OpenStrikeCombatEvents = root.get("combat_events")
    if best_target is OpenStrikeNetworkPlayer:
        var target: OpenStrikeNetworkPlayer = best_target
        if target.dead or target.team == str(root.get("player_team")):
            return true
        var was_alive := not target.dead
        target.health = maxi(0, target.health - damage)
        if target.health <= 0:
            target.mark_eliminated()
        if events != null:
            events.emit_hit("player", str(target.peer_id), weapon_id_value, damage, target.global_position, true)
        if was_alive and target.dead:
            if events != null:
                events.emit_elimination("player", str(target.peer_id), weapon_id_value, true)
        return true

    var target_team := str(best_target.get("team"))
    if best_target.has_method("take_damage") and target_team != str(root.get("player_team")):
        best_target.take_damage(damage, str(shooter.peer_id))
        if events != null:
            events.emit_hit("player", str(best_target.get_instance_id()), weapon_id_value, damage, best_target.global_position, true)
        return true
    return true


func _build_bot_snapshots(root: Node) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if root == null:
		return states
	var bots_value = root.get("bots")
	if not bots_value is Array:
		return states
	for bot in bots_value:
		if not is_instance_valid(bot) or not bot.is_in_group("bots"):
			continue
		var bot_id := int(bot.get("network_bot_id"))
		if bot_id <= 0:
			bot_id = int(bot.get("combat_slot")) + 1
		states.append({"id": bot_id, "position": bot.global_position, "velocity": bot.velocity, "yaw": bot.rotation.y, "health": int(bot.get("health")), "dead": bool(bot.get("dead")), "state": str(bot.get("state")), "assignment": str(bot.get("combat_assignment")), "round_number": int(root.get("round_number"))})
	return states
func _snapshot_server_players(delta: float) -> void:
	var root := _root()
	var current_round_state := str(root.get("round_state")) if root != null else "BUY"
	for peer_id in network_players.keys():
		var respawn_player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
		if is_instance_valid(respawn_player):
			respawn_player.tick_respawn(delta, current_round_state, _spawn_position_for_peer(int(peer_id)))
		_process_server_input(int(peer_id))
		var player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
		if is_instance_valid(player):
			# History is keyed to the server simulation tick, not the client command tick.
			# A late command is simulated now, so labeling that resulting state with its
			# old client tick would make the rewind history non-monotonic and inaccurate.
			player.record_snapshot(server_tick)

	snapshot_accumulator += delta
	if snapshot_accumulator < snapshot_interval:
		return
	snapshot_accumulator = 0.0
	var root := _root()
	if root == null:
		return
	for peer_id in network_players.keys():
		var player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
		if not is_instance_valid(player):
			continue
		var snapshot := player.make_snapshot(
			server_tick,
			str(root.get("round_state")),
			int(root.get("round_number")),
			str(root.get("objective_state")),
			str(root.get("planted_site")),
			float(root.get("bomb_time_left")),
			int(root.get("bomb_carrier_peer_id")),
			root.get("dropped_bomb_position") if root.get("dropped_bomb_position") is Vector3 else Vector3.ZERO,
			bool(root.get("round_won")),
			str(root.get("round_outcome_reason")),
			str(root.get("objective_action")),
			int(root.get("network_objective_peer_id")),
			float(root.get("objective_action_time_left"))
		)
		snapshot.bot_states = _build_bot_snapshots(root)
		snapshot.bot_count = snapshot.bot_states.size()
		broadcast_snapshot(snapshot)

func set_server_tick(tick: int) -> void:
	server_tick = maxi(0, tick)

func send_input(command: OpenStrikeInputCommand) -> void:
	if not is_online or is_server:
		return
	local_input_sequence = maxi(local_input_sequence, command.sequence)
	_submit_input.rpc_id(1, command.to_dict())

func broadcast_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if not is_online or not is_server:
		return
	_broadcast_snapshot.rpc(snapshot.to_dict())

func broadcast_snapshot_to_peer(peer_id: int, snapshot: OpenStrikeSnapshot) -> void:
	if not is_online or not is_server or peer_id <= 0 or snapshot == null:
		return
	snapshot.peer_id = peer_id
	_broadcast_snapshot.rpc_id(peer_id, snapshot.to_dict())

func pop_server_input(peer_id: int) -> OpenStrikeInputCommand:
	if not is_server:
		return null
	return server_input_buffer.pop_next(peer_id)

func pending_server_input(peer_id: int) -> int:
	if not is_server:
		return 0
	return server_input_buffer.pending(peer_id)

func last_server_input_sequence(peer_id: int) -> int:
	if not is_server:
		return 0
	return server_input_buffer.last_sequence(peer_id)

func _valid_input_wire_types(payload: Dictionary) -> bool:
	# Input packets are untrusted. Reject missing or coercible values before
	# from_dict() can turn strings/numbers into gameplay commands.
	var integer_fields := ["sequence", "tick"]
	for field in integer_fields:
		if not payload.has(field) or not payload[field] is int:
			return false
	var vector_fields := ["move", "look_delta"]
	for field in vector_fields:
		if not payload.has(field) or not payload[field] is Vector2:
			return false
	var boolean_fields := ["fire", "reload", "crouch", "jump", "objective", "switch_weapon"]
	for field in boolean_fields:
		if not payload.has(field) or not payload[field] is bool:
			return false
	var string_fields := ["weapon_id", "buy_weapon_id"]
	for field in string_fields:
		if not payload.has(field) or not payload[field] is String:
			return false
	if payload.weapon_id.length() > 64 or payload.buy_weapon_id.length() > 64:
		return false
	return true

@rpc("any_peer", "unreliable_ordered", INPUT_CHANNEL)
func _submit_input(payload: Dictionary) -> void:
	if not is_server:
		return
	if payload == null:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _valid_input_wire_types(payload):
		_reject_input(peer_id, OpenStrikeInputCommand.new(), "malformed_input_payload")
		return
	var command := OpenStrikeInputCommand.from_dict(payload)
	var root := _root()
	var round_state := str(root.get("round_state")) if root != null else "POST"
	var validation_reason := _validate_network_command(command, round_state)
	if validation_reason != "":
		_reject_input(peer_id, command, validation_reason)
		return
	var buffer_reason := server_input_buffer.submit(peer_id, command, server_tick)
	if buffer_reason != "":
		_reject_input(peer_id, command, buffer_reason)
		return
	input_received.emit(command)
	peer_input_received.emit(peer_id, command)

func _reject_input(peer_id: int, command: OpenStrikeInputCommand, reason: String) -> void:
	input_rejected.emit(peer_id, command)
	input_rejected_reason.emit(peer_id, command, reason)
	if peer_id > 0:
		var payload := command.to_dict()
		payload["rejection_reason"] = reason
		_notify_input_rejected.rpc_id(peer_id, payload)

@rpc("authority", "reliable", INPUT_CHANNEL)
func _notify_input_rejected(payload: Dictionary) -> void:
	if is_server:
		return
	if payload == null:
		return
	var command := OpenStrikeInputCommand.from_dict(payload)
	var reason := str(payload.get("rejection_reason", "input_rejected"))
	input_rejected.emit(1, command)
	input_rejected_reason.emit(1, command, reason)

@rpc("authority", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _broadcast_snapshot(payload: Dictionary) -> void:
	if is_server:
		return
	if not _valid_snapshot_wire_types(payload):
		_record_malformed_wire_snapshot()
		return
	var snapshot := OpenStrikeSnapshot.from_dict(payload)
	if not _accept_snapshot(snapshot):
		_record_snapshot_rejection(snapshot)
		return
	last_server_sequence = maxi(last_server_sequence, snapshot.acknowledged_input_sequence)
	_last_received_bot_count = snapshot.bot_count
	_apply_bot_snapshots(snapshot.bot_states)
	if snapshot.peer_id == multiplayer.get_unique_id():
		snapshot_received.emit(snapshot)
	else:
		_apply_remote_snapshot(snapshot)

func _valid_snapshot_wire_types(payload: Dictionary) -> bool:
	# Validate the raw Variant types before from_dict() performs coercions.
	# Otherwise strings/numbers could be silently converted into trusted state.
	var integer_fields := ["schema", "tick", "peer_id", "ack", "health", "round_number", "objective_action_peer_id", "carrier_peer_id", "ammo", "reserve", "credits", "bot_count"]
	for field in integer_fields:
		if not payload.has(field) or not payload[field] is int:
			return false
	var numeric_fields := ["yaw", "pitch", "objective_action_time_left", "bomb_time_left"]
	for field in numeric_fields:
		if not payload.has(field) or not (payload[field] is int or payload[field] is float):
			return false
	var vector_fields := ["position", "velocity", "dropped_bomb_position"]
	for field in vector_fields:
		if not payload.has(field) or not payload[field] is Vector3:
			return false
	var boolean_fields := ["dead", "crouched", "round_won"]
	for field in boolean_fields:
		if not payload.has(field) or not payload[field] is bool:
			return false
	var string_fields := ["round_state", "round_outcome_reason", "objective_state", "objective_action", "planted_site", "weapon_id"]
	for field in string_fields:
		if not payload.has(field) or not payload[field] is String:
			return false
	if not payload.has("owned_weapons") or not payload.owned_weapons is Array:
		return false
	if not payload.has("bot_states") or not payload.bot_states is Array:
		return false
	return true

func _record_malformed_wire_snapshot() -> void:
	var root := _root()
	if root == null:
		return
	var diagnostics = root.get("network_diagnostics")
	if diagnostics != null and diagnostics.has_method("record_rejected_snapshot"):
		diagnostics.record_rejected_snapshot(false)

func _record_snapshot_rejection(snapshot: OpenStrikeSnapshot) -> void:
	var root := _root()
	if root == null:
		return
	var diagnostics = root.get("network_diagnostics")
	if diagnostics == null or not diagnostics.has_method("record_rejected_snapshot"):
		return
	var malformed_roster := snapshot != null and snapshot.schema_version == SNAPSHOT_SCHEMA_VERSION and not _valid_bot_roster_payload(snapshot)
	diagnostics.record_rejected_snapshot(malformed_roster)

func _accept_snapshot(snapshot: OpenStrikeSnapshot) -> bool:
	if snapshot == null or snapshot.peer_id <= 0:
		return false
	if snapshot.schema_version != SNAPSHOT_SCHEMA_VERSION:
		return false
	if not _valid_snapshot_payload(snapshot):
		return false
	var peer_id := snapshot.peer_id
	var last_round := int(last_received_snapshot_round_by_peer.get(peer_id, -1))
	var last_tick := int(last_received_snapshot_tick_by_peer.get(peer_id, -1))
	if last_round >= 0:
		if snapshot.round_number < last_round:
			return false
		if snapshot.round_number == last_round and snapshot.tick < last_tick:
			return false
	last_received_snapshot_round_by_peer[peer_id] = snapshot.round_number
	last_received_snapshot_tick_by_peer[peer_id] = snapshot.tick
	return true

func _valid_snapshot_payload(snapshot: OpenStrikeSnapshot) -> bool:
	# Validate identity, sequence counters, and enum-like phase data before any
	# snapshot can advance per-peer acceptance bookkeeping.
	if snapshot.peer_id <= 0 or snapshot.tick < 0 or snapshot.acknowledged_input_sequence < 0:
		return false
	if snapshot.round_number < 1 or not ["BUY", "LIVE", "POST"].has(snapshot.round_state):
		return false
	if snapshot.weapon_id.length() > 64 or snapshot.round_outcome_reason.length() > 128:
		return false
	if snapshot.objective_state.length() > 32 or snapshot.objective_action.length() > 32 or snapshot.planted_site.length() > 32:
		return false
	if snapshot.carrier_peer_id < 0 or snapshot.objective_action_peer_id < -1:
		return false
	if not snapshot.position.is_finite() or not snapshot.velocity.is_finite():
		return false
	if not snapshot.dropped_bomb_position.is_finite():
		return false
	if not is_finite(snapshot.yaw) or not is_finite(snapshot.pitch):
		return false
	if absf(snapshot.pitch) > 1.46:
		return false
	if not is_finite(snapshot.bomb_time_left) or snapshot.bomb_time_left < 0.0:
		return false
	if not is_finite(snapshot.objective_action_time_left) or snapshot.objective_action_time_left < 0.0:
		return false
	if snapshot.health < 0 or snapshot.health > 100:
		return false
	if snapshot.ammo < 0 or snapshot.ammo > 1000 or snapshot.reserve < 0 or snapshot.reserve > 10000:
		return false
	if snapshot.credits < 0 or snapshot.credits > OpenStrikeNetworkPlayer.MAX_CREDITS:
		return false
	return _valid_owned_weapons_payload(snapshot) and _valid_bot_roster_payload(snapshot)

func _valid_owned_weapons_payload(snapshot: OpenStrikeSnapshot) -> bool:
	# Weapon ownership is authoritative inventory data. Reject coercible values,
	# duplicate IDs, and oversized lists before the snapshot reaches gameplay.
	if snapshot.owned_weapons.size() > 16:
		return false
	var seen_weapons := {}
	for weapon_value in snapshot.owned_weapons:
		if not weapon_value is String:
			return false
		var weapon_id: String = weapon_value
		if weapon_id.is_empty() or weapon_id.length() > 64 or seen_weapons.has(weapon_id):
			return false
		seen_weapons[weapon_id] = true
	return true

func _valid_bot_roster_payload(snapshot: OpenStrikeSnapshot) -> bool:
	if snapshot.bot_count < 0 or snapshot.bot_count > 15:
		return false
	if snapshot.bot_states.size() != snapshot.bot_count:
		return false
	var seen_ids := {}
	for state_value in snapshot.bot_states:
		if not state_value is Dictionary:
			return false
		# Validate wire types before any int()/float() conversion. The roster
		# is authoritative state, so coercible strings are not accepted.
		if not state_value.has("id") or not state_value.id is int:
			return false
		if not state_value.has("round_number") or not state_value.round_number is int:
			return false
		if not state_value.has("position") or not state_value.position is Vector3:
			return false
		if not state_value.has("velocity") or not state_value.velocity is Vector3:
			return false
		if not state_value.has("yaw") or not (state_value.yaw is int or state_value.yaw is float):
			return false
		if not state_value.has("health") or not state_value.health is int:
			return false
		if not state_value.has("dead") or not state_value.dead is bool:
			return false
		if not state_value.has("state") or not state_value.state is String:
			return false
		if not state_value.has("assignment") or not state_value.assignment is String:
			return false
		var bot_id: int = state_value.id
		if bot_id <= 0 or bot_id > snapshot.bot_count or seen_ids.has(bot_id):
			return false
		if not state_value.position.is_finite() or not state_value.velocity.is_finite():
			return false
		if not is_finite(float(state_value.yaw)):
			return false
		if state_value.health < 0 or state_value.health > 100:
			return false
		if state_value.round_number != snapshot.round_number:
			return false
		seen_ids[bot_id] = true
	# Require the complete stable ID range at validation time, not only during
	# client application. This keeps malformed rosters out of accepted snapshot
	# bookkeeping and ensures rejection diagnostics classify them correctly.
	for expected_bot_id in range(1, snapshot.bot_count + 1):
		if not seen_ids.has(expected_bot_id):
			return false
	return true

func _reset_snapshot_receive_state() -> void:
	last_received_snapshot_tick_by_peer.clear()
	last_received_snapshot_round_by_peer.clear()
	_last_received_bot_count = -1

func _apply_remote_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if snapshot == null or snapshot.peer_id <= 0:
		return
	var player := _spawn_network_player(snapshot.peer_id)
	if player == null:
		return
	player.apply_snapshot(snapshot)

func _refresh_network_bot_cache() -> void:
	var root := _root()
	if root == null:
		network_bot_cache.clear()
		return
	var bots_value = root.get("bots")
	if not bots_value is Array:
		network_bot_cache.clear()
		return
	var rebuilt := {}
	for bot in bots_value:
		if not is_instance_valid(bot):
			continue
		var bot_id := int(bot.get("network_bot_id"))
		if bot_id <= 0:
			bot_id = int(bot.get("combat_slot")) + 1
		if bot_id > 0:
			rebuilt[bot_id] = bot
	network_bot_cache = rebuilt

func _apply_bot_snapshots(states: Array[Dictionary]) -> void:
	var root := _root()
	var roster_changed := false
	if root != null and not is_server and root.has_method("configure_network_bot_count"):
		var authoritative_count := states.size()
		if _last_received_bot_count >= 0:
			authoritative_count = _last_received_bot_count
		# A snapshot is delivered as one RPC payload. A count/state mismatch is
		# therefore malformed rather than a partial roster update; never create
		# client-side bots from a roster whose state list is inconsistent.
		if authoritative_count != states.size() or authoritative_count > 15:
			return
		var seen_bot_ids := {}
		for state_value in states:
			if not state_value is Dictionary:
				return
			var state_bot_id := int(state_value.get("id", 0))
			if state_bot_id <= 0 or state_bot_id > authoritative_count or seen_bot_ids.has(state_bot_id):
				return
			seen_bot_ids[state_bot_id] = true
		# The server assigns stable IDs from 1..bot_count. Requiring the full
		# contiguous set prevents a malformed payload from silently leaving a
		# locally-created bot without an authoritative state.
		for expected_bot_id in range(1, authoritative_count + 1):
			if not seen_bot_ids.has(expected_bot_id):
				return
		roster_changed = bool(root.configure_network_bot_count(authoritative_count))
	if roster_changed:
		_refresh_network_bot_cache()
	if network_bot_cache.is_empty():
		_refresh_network_bot_cache()
	if states.is_empty():
		return
	for state_value in states:
		if not state_value is Dictionary:
			continue
		var bot_id := int(state_value.get("id", 0))
		if bot_id <= 0:
			continue
		var bot = network_bot_cache.get(bot_id)
		if not is_instance_valid(bot):
			_refresh_network_bot_cache()
			bot = network_bot_cache.get(bot_id)
		if is_instance_valid(bot) and bot.has_method("apply_network_snapshot"):
			bot.apply_network_snapshot(state_value)
func _clear_session_state() -> void:
	# Drop transient state from the previous connection so a failed/replaced
	# session cannot leak stale players, acknowledgements, or bot references.
	server_input_buffer.clear()
	for peer_value in network_players.keys():
		_remove_network_player(int(peer_value))
	network_players.clear()
	network_bot_cache.clear()
	_reset_snapshot_receive_state()
	local_input_sequence = 0
	last_server_sequence = 0
	server_tick = 0
	snapshot_accumulator = 0.0
	observed_round_number = 0
	observed_round_state = ""

func _shutdown_peer() -> void:
	_clear_session_state()
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
