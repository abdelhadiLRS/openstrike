class_name OpenStrikeCombatValidator
extends RefCounted

enum RejectReason {
	NONE,
	ROUND_NOT_LIVE,
	PLAYER_DEAD,
	WEAPON_INVALID,
	WEAPON_NOT_OWNED,
	COOLDOWN_ACTIVE,
	NO_AMMO,
	INVALID_TARGET,
	FRIENDLY_TARGET,
	INVALID_DAMAGE
}

class Result:
	var accepted: bool
	var reason: RejectReason
	var message: String

	func _init(is_accepted: bool, rejection_reason: RejectReason = RejectReason.NONE, detail: String = "") -> void:
		accepted = is_accepted
		reason = rejection_reason
		message = detail

static func validate_fire(
	round_state: String,
	is_dead: bool,
	weapon: Dictionary,
	weapon_owned: bool,
	cooldown: float,
	ammo: int,
	target: Node = null,
	shooter_team: String = "",
	damage: int = 0
) -> Result:
	if round_state != "LIVE":
		return Result.new(false, RejectReason.ROUND_NOT_LIVE, "Combat is not live.")
	if is_dead:
		return Result.new(false, RejectReason.PLAYER_DEAD, "Shooter is dead.")
	if weapon.is_empty() or not weapon.has("id") or not weapon.has("damage") or not weapon.has("delay"):
		return Result.new(false, RejectReason.WEAPON_INVALID, "Weapon definition is invalid.")
	if not weapon_owned:
		return Result.new(false, RejectReason.WEAPON_NOT_OWNED, "Weapon is not owned.")
	if cooldown > 0.0001:
		return Result.new(false, RejectReason.COOLDOWN_ACTIVE, "Weapon cooldown is active.")
	if ammo <= 0:
		return Result.new(false, RejectReason.NO_AMMO, "Magazine is empty.")
	if damage <= 0 or damage > 1000:
		return Result.new(false, RejectReason.INVALID_DAMAGE, "Damage value is outside the allowed range.")

	if target != null:
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			return Result.new(false, RejectReason.INVALID_TARGET, "Target cannot receive damage.")
		var target_team := str(target.get("team"))
		if target_team == shooter_team:
			return Result.new(false, RejectReason.FRIENDLY_TARGET, "Friendly fire target rejected.")

	return Result.new(true)

static func validate_reload(round_state: String, is_dead: bool, weapon: Dictionary, ammo: int, reserve: int) -> Result:
	if round_state != "LIVE":
		return Result.new(false, RejectReason.ROUND_NOT_LIVE, "Reload is only allowed during live combat.")
	if is_dead:
		return Result.new(false, RejectReason.PLAYER_DEAD, "Dead players cannot reload.")
	if weapon.is_empty() or not weapon.has("mag"):
		return Result.new(false, RejectReason.WEAPON_INVALID, "Weapon definition is invalid.")
	if ammo < 0 or reserve < 0:
		return Result.new(false, RejectReason.NO_AMMO, "Ammo state cannot be negative.")
	return Result.new(true)
