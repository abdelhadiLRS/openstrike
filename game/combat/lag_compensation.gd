class_name OpenStrikeLagCompensation
extends RefCounted

static func rewind_position(history: OpenStrikeSnapshotHistory, requested_tick: int) -> Vector3:
	if history == null:
		return Vector3.ZERO
	var snapshot := history.at_or_before(requested_tick)
	if snapshot == null:
		return Vector3.ZERO
	return snapshot.position

static func clamp_requested_tick(requested_tick: int, current_tick: int, max_rewind_ticks: int) -> int:
	var oldest_allowed := maxi(0, current_tick - maxi(0, max_rewind_ticks))
	return clampi(requested_tick, oldest_allowed, current_tick)
