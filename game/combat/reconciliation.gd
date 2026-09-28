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
