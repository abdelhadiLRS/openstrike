class_name OpenStrikeServerInputBuffer
extends RefCounted

const MAX_PENDING := 32
const MAX_MOVE := 1.0
const MAX_LOOK_DELTA := 120.0
const MAX_TICK_LEAD := 8
const MAX_REWIND_TICKS := 64

var _queues: Dictionary = {}
var _last_sequence: Dictionary = {}
var _last_tick: Dictionary = {}

func submit(peer_id: int, command: OpenStrikeInputCommand, server_tick: int) -> bool:
	if peer_id <= 0 or command == null:
		return false
	# Reject non-finite client values before they reach CharacterBody3D
	# movement, camera rotation, or weapon/objective simulation.
	if not command.move.is_finite() or not command.look_delta.is_finite():
		return false
	if command.sequence <= int(_last_sequence.get(peer_id, 0)):
		return false
	if command.tick > server_tick + MAX_TICK_LEAD:
		return false
	if command.tick < server_tick - MAX_REWIND_TICKS:
		return false
	var previous_tick := int(_last_tick.get(peer_id, -1))
	if previous_tick >= 0 and command.tick < previous_tick:
		return false

	command.move = command.move.limit_length(MAX_MOVE)
	command.look_delta.x = clampf(command.look_delta.x, -MAX_LOOK_DELTA, MAX_LOOK_DELTA)
	command.look_delta.y = clampf(command.look_delta.y, -MAX_LOOK_DELTA, MAX_LOOK_DELTA)

	var queue: Array = _queues.get(peer_id, [])
	if queue.size() >= MAX_PENDING:
		queue.pop_front()
	queue.append(command)
	_queues[peer_id] = queue
	_last_sequence[peer_id] = command.sequence
	_last_tick[peer_id] = command.tick
	return true

func pop_next(peer_id: int) -> OpenStrikeInputCommand:
	var queue: Array = _queues.get(peer_id, [])
	if queue.is_empty():
		return null
	var command: OpenStrikeInputCommand = queue.pop_front()
	_queues[peer_id] = queue
	return command

func pending(peer_id: int) -> int:
	return Array(_queues.get(peer_id, [])).size()

func last_sequence(peer_id: int) -> int:
	return int(_last_sequence.get(peer_id, 0))

func clear_peer(peer_id: int) -> void:
	_queues.erase(peer_id)
	_last_sequence.erase(peer_id)
	_last_tick.erase(peer_id)

func clear() -> void:
	_queues.clear()
	_last_sequence.clear()
	_last_tick.clear()
