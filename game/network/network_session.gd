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

var server_input_buffer := OpenStrikeServerInputBuffer.new()
var server_tick := 0


const DEFAULT_PORT := 27015
const MAX_CLIENTS := 16
const KILL_REWARD := 300
const ROUND_WIN_REWARD := 2200
const ROUND_LOSS_REWARD := 1200
const INPUT_CHANNEL := 0
const SNAPSHOT_CHANNEL := 1

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

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	_shutdown_peer()
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
	connected.emit()

func _on_connection_failed() -> void:
	is_online = false
	is_server = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	is_online = false
	is_server = false
	disconnected.emit()

func _on_peer_connected(peer_id: int) -> void:
	if is_server and peer_id > 0:
		peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id > 0:
		server_input_buffer.clear_peer(peer_id)
		_remove_network_player(peer_id)
		var root := _root()
		if root != null and root.has_method("set_network_objective_input"):
			root.set_network_objective_input(peer_id, false)
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

func _process_server_input(peer_id: int, delta: float) -> void:
	var player := _spawn_network_player(peer_id)
	if player == null:
		return
	var command := server_input_buffer.pop_next(peer_id)
	if command == null:
		return
	var root := _root()
	var round_state := str(root.get("round_state")) if root != null else "BUY"
	player.apply_input(command, delta, round_state)
	var root_for_objective := _root()
	if root_for_objective != null and root_for_objective.has_method("set_network_objective_input"):
		root_for_objective.set_network_objective_input(peer_id, command.objective)
	player.record_snapshot(server_tick)
	if command.fire and round_state == "LIVE":
		_process_server_fire(player, command)

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
		var historical := OpenStrikeLagCompensation.rewind_position(target.snapshot_history, requested_tick)
		if historical == Vector3.ZERO:
			continue
		historical += Vector3(0, 0.65, 0)
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


func _snapshot_server_players(delta: float) -> void:
	var root := _root()
	var current_round_state := str(root.get("round_state")) if root != null else "BUY"
	for peer_id in network_players.keys():
		var respawn_player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
		if is_instance_valid(respawn_player):
			respawn_player.tick_respawn(delta, current_round_state, _spawn_position_for_peer(int(peer_id)))
		var player: OpenStrikeNetworkPlayer = network_players.get(peer_id)
		if is_instance_valid(player):
			player.record_snapshot(server_tick)
		_process_server_input(int(peer_id), delta)

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
			bool(root.get("round_won")),
			str(root.get("round_outcome_reason"))
		)
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

@rpc("any_peer", "unreliable_ordered", INPUT_CHANNEL)
func _submit_input(payload: Dictionary) -> void:
	if not is_server:
		return
	var move_value = payload.get("move", Vector2.ZERO)
	var look_value = payload.get("look_delta", Vector2.ZERO)
	if not move_value is Vector2 or not look_value is Vector2:
		return
	var command := OpenStrikeInputCommand.new()
	command.sequence = int(payload.get("sequence", 0))
	command.tick = int(payload.get("tick", 0))
	command.weapon_id = str(payload.get("weapon_id", "px_9"))
	command.buy_weapon_id = str(payload.get("buy_weapon_id", ""))
	command.switch_weapon = bool(payload.get("switch_weapon", false))
	command.move = move_value
	command.look_delta = look_value
	command.fire = bool(payload.get("fire", false))
	command.reload = bool(payload.get("reload", false))
	command.crouch = bool(payload.get("crouch", false))
	command.jump = bool(payload.get("jump", false))
	command.objective = bool(payload.get("objective", false))
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0 or not server_input_buffer.submit(peer_id, command, server_tick):
		return
	input_received.emit(command)
	peer_input_received.emit(peer_id, command)

@rpc("authority", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _broadcast_snapshot(payload: Dictionary) -> void:
	if is_server:
		return
	var snapshot := OpenStrikeSnapshot.from_dict(payload)
	last_server_sequence = maxi(last_server_sequence, snapshot.acknowledged_input_sequence)
	if snapshot.peer_id == multiplayer.get_unique_id():
		snapshot_received.emit(snapshot)
	else:
		_apply_remote_snapshot(snapshot)

func _apply_remote_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if snapshot == null or snapshot.peer_id <= 0:
		return
	var player := _spawn_network_player(snapshot.peer_id)
	if player == null:
		return
	player.apply_snapshot(snapshot)

func _shutdown_peer() -> void:
	server_input_buffer.clear()

	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
