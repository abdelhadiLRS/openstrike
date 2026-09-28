class_name OpenStrikePredictionBuffer
extends RefCounted

class PredictedState:
	var sequence: int
	var position: Vector3
	var velocity: Vector3
	var yaw: float
	var pitch: float

	func _init(sequence_value: int, position_value: Vector3, velocity_value: Vector3, yaw_value: float, pitch_value: float) -> void:
		sequence = sequence_value
		position = position_value
		velocity = velocity_value
		yaw = yaw_value
		pitch = pitch_value

const MAX_COMMANDS := 128
var pending_commands: Array[OpenStrikeInputCommand] = []
var predicted_states: Array[PredictedState] = []

func push(command: OpenStrikeInputCommand, position: Vector3, velocity: Vector3, yaw: float, pitch: float) -> void:
	pending_commands.push_back(command)
	predicted_states.push_back(PredictedState.new(command.sequence, position, velocity, yaw, pitch))
	if pending_commands.size() > MAX_COMMANDS:
		pending_commands.pop_front()
		predicted_states.pop_front()

func acknowledge(sequence: int) -> void:
	while not pending_commands.is_empty() and pending_commands[0].sequence <= sequence:
		pending_commands.pop_front()
	if predicted_states.size() > 0:
		while not predicted_states.is_empty() and predicted_states[0].sequence <= sequence:
			predicted_states.pop_front()

func pending_count() -> int:
	return pending_commands.size()

func pending_commands_snapshot() -> Array[OpenStrikeInputCommand]:
	var commands: Array[OpenStrikeInputCommand] = []
	for command in pending_commands:
		if command != null:
			commands.append(command)
	return commands

func clear() -> void:
	pending_commands.clear()
	predicted_states.clear()
