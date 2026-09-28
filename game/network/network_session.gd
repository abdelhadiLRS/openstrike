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

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

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
	is_online = true
	connected.emit()
	return OK

func shutdown() -> void:
	_shutdown_peer()
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
		peer_disconnected.emit(peer_id)

func _physics_process(delta: float) -> void:
	if not is_server or not is_online:
		return
	_snapshot_server_players(delta)

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
	var spawn_points: Array = root.get("blue_spawn_points") if root.get("blue_spawn_points") is Array else []
	var spawn := Vector3.ZERO
	if not spawn_points.is_empty():
		spawn = spawn_points[(peer_id - 1) % spawn_points.size()]
	player.setup(peer_id, spawn)
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
	if root != null and str(root.get("round_state")) != "LIVE":
		player.last_processed_sequence = maxi(player.last_processed_sequence, command.sequence)
		return
	player.apply_input(command, delta)

func _snapshot_server_players(delta: float) -> void:
	for peer_id in network_players.keys():
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
			float(root.get("bomb_time_left"))
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
	var command := OpenStrikeInputCommand.new()
	command.sequence = int(payload.get("sequence", 0))
	command.tick = int(payload.get("tick", 0))
	command.move = payload.get("move", Vector2.ZERO)
	command.look_delta = payload.get("look_delta", Vector2.ZERO)
	command.fire = bool(payload.get("fire", false))
	command.reload = bool(payload.get("reload", false))
	command.crouch = bool(payload.get("crouch", false))
	command.jump = bool(payload.get("jump", false))
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
