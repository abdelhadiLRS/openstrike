class_name OpenStrikeSnapshotHistory
extends RefCounted

class Snapshot:
	var tick: int
	var position: Vector3
	var rotation_y: float
	var health: int
	var timestamp_usec: int

	func _init(
		tick_value: int,
		position_value: Vector3,
		rotation_value: float,
		health_value: int
	) -> void:
		tick = tick_value
		position = position_value
		rotation_y = rotation_value
		health = health_value
		timestamp_usec = Time.get_ticks_usec()

const MAX_SNAPSHOTS := 64

var _snapshots: Array[Snapshot] = []

func push(tick: int, position: Vector3, rotation_y: float, health: int) -> void:
	if not _snapshots.is_empty():
		var latest_tick := _snapshots.back().tick
		if tick < latest_tick:
			return
		if tick == latest_tick:
			_snapshots[_snapshots.size() - 1] = Snapshot.new(tick, position, rotation_y, health)
			return
	_snapshots.push_back(Snapshot.new(tick, position, rotation_y, health))
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()

func latest() -> Snapshot:
	if _snapshots.is_empty():
		return null
	return _snapshots.back()

func at_or_before(tick: int) -> Snapshot:
	var result: Snapshot = null
	for snapshot in _snapshots:
		if snapshot.tick > tick:
			break
		result = snapshot
	return result

func clear() -> void:
	_snapshots.clear()

func size() -> int:
	return _snapshots.size()
