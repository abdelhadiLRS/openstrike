class_name OpenStrikeNetworkSession
extends Node

## Lightweight Godot-native networking boundary.
## Gameplay remains usable offline; this layer becomes active only when a host/client is started.

signal connected
signal disconnected
signal connection_failed
signal input_received(command: OpenStrikeInputCommand)
signal snapshot_received(snapshot: OpenStrikeSnapshot)

const DEFAULT_PORT := 27015
const MAX_CLIENTS := 16
const INPUT_CHANNEL := 0
const SNAPSHOT_CHANNEL := 1

var peer: ENetMultiplayerPeer
var is_server := false
var is_online := false
var local_input_sequence := 0
var last_server_sequence := 0

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

func send_input(command: OpenStrikeInputCommand) -> void:
	if not is_online or is_server:
		return
	local_input_sequence = maxi(local_input_sequence, command.sequence)
	_submit_input.rpc_id(1, command.to_dict())

func broadcast_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if not is_online or not is_server:
		return
	_broadcast_snapshot.rpc(snapshot.to_dict())

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
	input_received.emit(command)

@rpc("authority", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _broadcast_snapshot(payload: Dictionary) -> void:
	if is_server:
		return
	var snapshot := OpenStrikeSnapshot.from_dict(payload)
	last_server_sequence = maxi(last_server_sequence, snapshot.acknowledged_input_sequence)
	snapshot_received.emit(snapshot)

func _shutdown_peer() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
