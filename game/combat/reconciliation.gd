class_name OpenStrikeReconciliation
extends RefCounted

static func correction_needed(
	authoritative_position: Vector3,
	predicted_position: Vector3,
	max_error: float = 0.15
) -> bool:
	return authoritative_position.distance_to(predicted_position) > max_error

static func corrected_position(
	authoritative_position: Vector3,
	predicted_position: Vector3,
	correction_alpha: float = 0.35
) -> Vector3:
	return predicted_position.lerp(authoritative_position, clampf(correction_alpha, 0.0, 1.0))

static func rotation_correction_needed(
	authoritative_yaw: float,
	predicted_yaw: float,
	authoritative_pitch: float,
	predicted_pitch: float,
	max_angle_error: float = 0.08
) -> bool:
	var yaw_error := absf(wrapf(authoritative_yaw - predicted_yaw, -PI, PI))
	var pitch_error := absf(authoritative_pitch - predicted_pitch)
	return yaw_error > max_angle_error or pitch_error > max_angle_error

static func corrected_angle(
	authoritative_angle: float,
	predicted_angle: float,
	correction_alpha: float = 0.35
) -> float:
	var delta := wrapf(authoritative_angle - predicted_angle, -PI, PI)
	return predicted_angle + delta * clampf(correction_alpha, 0.0, 1.0)

static func corrected_velocity(
	authoritative_velocity: Vector3,
	predicted_velocity: Vector3,
	correction_alpha: float = 0.25
) -> Vector3:
	return predicted_velocity.lerp(authoritative_velocity, clampf(correction_alpha, 0.0, 1.0))
