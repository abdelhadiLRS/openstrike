class_name OpenStrikePredictionController
extends RefCounted

## Coordinates local prediction bookkeeping without owning movement.
## The existing CharacterBody3D movement remains the source of truth for simulation.
var buffer := OpenStrikePredictionBuffer.new()
var next_sequence: int = 0
var last_acknowledged_sequence: int = 0

func build_command(tick: int, move: Vector2, look_delta: Vector2, fire: bool, reload: bool, crouch: bool, jump: bool, weapon_id: String = "px_9", objective: bool = false) -> OpenStrikeInputCommand:
	next_sequence += 1
	var command := OpenStrikeInputCommand.new()
	command.sequence = next_sequence
	command.tick = tick
	command.move = move
	command.look_delta = look_delta
	command.fire = fire
	command.reload = reload
	command.crouch = crouch
	command.jump = jump
	command.objective = objective
	command.weapon_id = weapon_id
	return command

func record_predicted(command: OpenStrikeInputCommand, position: Vector3, velocity: Vector3, yaw: float, pitch: float) -> void:
	buffer.push(command, position, velocity, yaw, pitch)

func acknowledge(sequence: int) -> void:
	if sequence <= last_acknowledged_sequence:
		return
	last_acknowledged_sequence = sequence
	buffer.acknowledge(sequence)

func pending_count() -> int:
	return buffer.pending_count()

func reset() -> void:
	next_sequence = 0
	last_acknowledged_sequence = 0
	buffer.clear()
