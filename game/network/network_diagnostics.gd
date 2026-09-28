class_name OpenStrikeNetworkDiagnostics
extends RefCounted

var sent_commands: int = 0
var received_snapshots: int = 0
var rejected_inputs: int = 0
var snapshot_tick_gaps: int = 0
var prediction_corrections: int = 0
var rejected_snapshots: int = 0
var malformed_bot_rosters: int = 0
var last_acknowledged_sequence: int = 0
var last_snapshot_tick: int = 0
var last_snapshot_tick_by_peer: Dictionary = {}
var last_snapshot_round_by_peer: Dictionary = {}
var rejection_reasons: Dictionary = {}

func record_command() -> void:
	sent_commands += 1

func record_snapshot(peer_id: int, tick: int, round_number: int, acknowledged_sequence: int) -> void:
	var previous_round := int(last_snapshot_round_by_peer.get(peer_id, -1))
	var previous_tick := int(last_snapshot_tick_by_peer.get(peer_id, -1))
	# Tick counters may continue across rounds, but diagnostics must never
	# interpret a round transition as packet loss.
	if previous_round == round_number and previous_tick >= 0 and tick > previous_tick + 1:
		snapshot_tick_gaps += tick - previous_tick - 1
	if previous_round < 0 or round_number > previous_round or tick > previous_tick:
		last_snapshot_round_by_peer[peer_id] = round_number
		last_snapshot_tick_by_peer[peer_id] = tick
	last_snapshot_tick = maxi(last_snapshot_tick, tick)
	last_acknowledged_sequence = maxi(last_acknowledged_sequence, acknowledged_sequence)
	received_snapshots += 1

func record_peer_disconnected(peer_id: int) -> void:
	if peer_id <= 0:
		return
	last_snapshot_tick_by_peer.erase(peer_id)
	last_snapshot_round_by_peer.erase(peer_id)

func record_rejected_input() -> void:
	rejected_inputs += 1

func record_rejection_reason(reason: String) -> void:
	if reason.is_empty():
		return
	rejection_reasons[reason] = int(rejection_reasons.get(reason, 0)) + 1

func record_prediction_correction() -> void:
	prediction_corrections += 1

func record_rejected_snapshot(malformed_roster: bool = false) -> void:
	rejected_snapshots += 1
	if malformed_roster:
		malformed_bot_rosters += 1

func snapshot() -> Dictionary:
	return {
		"sent_commands": sent_commands,
		"received_snapshots": received_snapshots,
		"rejected_inputs": rejected_inputs,
		"snapshot_tick_gaps": snapshot_tick_gaps,
		"prediction_corrections": prediction_corrections,
		"rejected_snapshots": rejected_snapshots,
		"malformed_bot_rosters": malformed_bot_rosters,
		"last_acknowledged_sequence": last_acknowledged_sequence,
		"last_snapshot_tick": last_snapshot_tick,
		"rejection_reasons": rejection_reasons.duplicate()
	}
