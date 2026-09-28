class_name OpenStrikeNetworkDiagnostics
extends RefCounted

var sent_commands: int = 0
var received_snapshots: int = 0
var rejected_inputs: int = 0
var sequence_gaps: int = 0
var prediction_corrections: int = 0
var last_acknowledged_sequence: int = 0
var last_snapshot_tick: int = 0

func record_command() -> void:
	sent_commands += 1

func record_snapshot(tick: int, acknowledged_sequence: int) -> void:
	if last_snapshot_tick > 0 and tick > last_snapshot_tick + 1:
		sequence_gaps += tick - last_snapshot_tick - 1
	last_snapshot_tick = maxi(last_snapshot_tick, tick)
	last_acknowledged_sequence = maxi(last_acknowledged_sequence, acknowledged_sequence)
	received_snapshots += 1

func record_rejected_input() -> void:
	rejected_inputs += 1

func record_prediction_correction() -> void:
	prediction_corrections += 1

func snapshot() -> Dictionary:
	return {
		"sent_commands": sent_commands,
		"received_snapshots": received_snapshots,
		"rejected_inputs": rejected_inputs,
		"sequence_gaps": sequence_gaps,
		"prediction_corrections": prediction_corrections,
		"last_acknowledged_sequence": last_acknowledged_sequence,
		"last_snapshot_tick": last_snapshot_tick
	}
