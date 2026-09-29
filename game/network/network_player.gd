class_name OpenStrikeNetworkPlayer
extends CharacterBody3D

const GRAVITY := 14.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_SPEED := 5.6
const CROUCH_SPEED := 3.4
const STARTING_CREDITS := 1200
const MAX_CREDITS := 16000
const RESPAWN_DELAY := 2.0

var peer_id: int = 0
var team: String = "BLUE"
var health: int = 100
var dead: bool = false
var crouched: bool = false
var yaw: float = 0.0
var pitch: float = 0.0
var last_processed_sequence: int = 0
var weapon_id: String = "px_9"
var ammo: int = 12
var reserve: int = 48
var fire_cooldown: float = 0.0
var primary_owned: bool = false
var credits: int = STARTING_CREDITS
var weapon_states: Dictionary = {}
var respawn_timer: float = 0.0
var snapshot_history := OpenStrikeSnapshotHistory.new()

# Remote clients receive snapshots at a lower rate than the render/physics loop.
# Keep the authoritative target separate so remote players move smoothly instead
# of visibly stepping from one network packet to the next.
var snapshot_target_position := Vector3.ZERO
var snapshot_target_yaw: float = 0.0
var snapshot_target_pitch: float = 0.0
var has_snapshot_target: bool = false
var snapshot_smoothing_speed: float = 18.0

# Keep a tiny authoritative history for render-time interpolation. Rendering
# slightly behind the newest server tick prevents packet jitter from becoming
# visible acceleration/deceleration while keeping the gameplay state current.
const SNAPSHOT_BUFFER_MAX := 6
const SNAPSHOT_INTERPOLATION_TICKS := 6
var snapshot_buffer: Array[OpenStrikeSnapshot] = []
var snapshot_render_tick: float = 0.0

var collision_shape: CollisionShape3D
var mesh: MeshInstance3D
var visual_root: Node3D

func _physics_process(delta: float) -> void:
	_update_visual_pose(delta)
	if not has_snapshot_target:
		return
	if snapshot_buffer.size() >= 2:
		_update_buffered_transform(delta)
		return
	var blend := 1.0 - exp(-snapshot_smoothing_speed * maxf(delta, 0.0))
	global_position = global_position.lerp(snapshot_target_position, blend)
	var yaw_delta := wrapf(snapshot_target_yaw - rotation.y, -PI, PI)
	rotation.y += yaw_delta * blend
	yaw = rotation.y
	pitch = lerpf(pitch, snapshot_target_pitch, blend)

func _update_visual_pose(delta: float) -> void:
	if visual_root == null:
		return
	# Compress only the render model while crouched; the authoritative capsule
	# remains controlled by _update_collider() and is never scaled visually.
	var target_scale_y := 0.68 if crouched else 1.0
	var target_offset_y := -0.24 if crouched else 0.0
	var blend := 1.0 - exp(-12.0 * maxf(delta, 0.0))
	visual_root.scale.y = lerpf(visual_root.scale.y, target_scale_y, blend)
	visual_root.position.y = lerpf(visual_root.position.y, target_offset_y, blend)

func _update_buffered_transform(delta: float) -> void:
	var latest := snapshot_buffer[snapshot_buffer.size() - 1]
	if latest == null:
		return
	var desired_tick := float(latest.tick - SNAPSHOT_INTERPOLATION_TICKS)
	snapshot_render_tick = move_toward(snapshot_render_tick, desired_tick, maxf(delta, 0.0) * 60.0)
	if snapshot_render_tick > desired_tick:
		snapshot_render_tick = desired_tick

	var from_snapshot: OpenStrikeSnapshot = null
	var to_snapshot: OpenStrikeSnapshot = null
	for index in range(snapshot_buffer.size() - 1):
		var a := snapshot_buffer[index]
		var b := snapshot_buffer[index + 1]
		if a == null or b == null:
			continue
		if float(a.tick) <= snapshot_render_tick and snapshot_render_tick <= float(b.tick):
			from_snapshot = a
			to_snapshot = b
			break

	if from_snapshot == null or to_snapshot == null:
		# If the newest packet has not advanced far enough to fill the delayed
		# render point, keep the latest buffered target rather than extrapolating
		# aggressively. This is safer for collision-sensitive FPS visuals.
		var blend := 1.0 - exp(-snapshot_smoothing_speed * maxf(delta, 0.0))
		global_position = global_position.lerp(snapshot_target_position, blend)
		var yaw_delta := wrapf(snapshot_target_yaw - rotation.y, -PI, PI)
		rotation.y += yaw_delta * blend
		yaw = rotation.y
		pitch = lerpf(pitch, snapshot_target_pitch, blend)
		return

	var tick_span := maxf(1.0, float(to_snapshot.tick - from_snapshot.tick))
	var alpha := clampf((snapshot_render_tick - float(from_snapshot.tick)) / tick_span, 0.0, 1.0)
	var target_position := from_snapshot.position.lerp(to_snapshot.position, alpha)
	var target_yaw := from_snapshot.yaw + wrapf(to_snapshot.yaw - from_snapshot.yaw, -PI, PI) * alpha
	var target_pitch := lerpf(from_snapshot.pitch, to_snapshot.pitch, alpha)
	var blend := 1.0 - exp(-snapshot_smoothing_speed * maxf(delta, 0.0))
	global_position = global_position.lerp(target_position, blend)
	var yaw_delta := wrapf(target_yaw - rotation.y, -PI, PI)
	rotation.y += yaw_delta * blend
	yaw = rotation.y
	pitch = lerpf(pitch, target_pitch, blend)

func setup(id: int, start_position: Vector3, catalog: Array = []) -> void:
	peer_id = id
	team = "BLUE"
	global_position = start_position
	snapshot_target_position = start_position
	snapshot_buffer.clear()
	snapshot_render_tick = 0.0
	snapshot_history.clear()
	has_snapshot_target = false
	yaw = rotation.y
	_initialize_weapon_states(catalog)
	_build_visual()

func _initialize_weapon_states(catalog: Array) -> void:
	weapon_states.clear()
	for definition in catalog:
		if not definition is Dictionary:
			continue
		var id := str(definition.get("id", ""))
		if id.is_empty():
			continue
		var state := OpenStrikeWeaponRuntimeState.from_definition(definition, id == "px_9")
		weapon_states[id] = state
	primary_owned = false
	_select_weapon("px_9")

func _weapon_state(id: String = weapon_id) -> OpenStrikeWeaponRuntimeState:
	var state = weapon_states.get(id)
	return state if state is OpenStrikeWeaponRuntimeState else null

func _select_weapon(requested_id: String) -> bool:
	var state := _weapon_state(requested_id)
	if state == null or not state.owned:
		return false
	weapon_id = requested_id
	_sync_active_weapon()
	return true

func _sync_active_weapon() -> void:
	var state := _weapon_state()
	if state == null:
		return
	ammo = state.ammo
	reserve = state.reserve_ammo
	fire_cooldown = state.cooldown_remaining

func begin_round(start_position: Vector3) -> void:
	global_position = start_position
	snapshot_target_position = start_position
	snapshot_buffer.clear()
	snapshot_render_tick = 0.0
	snapshot_history.clear()
	has_snapshot_target = false
	velocity = Vector3.ZERO
	health = 100
	dead = false
	respawn_timer = 0.0
	crouched = false
	primary_owned = false
	weapon_id = "px_9"
	for state in weapon_states.values():
		if state is OpenStrikeWeaponRuntimeState:
			state.owned = state.weapon_id == "px_9"
			state.set_loaded_state(state.magazine_size, state.reserve_ammo)
			state.cooldown_remaining = 0.0
	_select_weapon("px_9")
	_sync_active_weapon()

func begin_respawn(start_position: Vector3) -> void:
	global_position = start_position
	snapshot_target_position = start_position
	snapshot_buffer.clear()
	snapshot_render_tick = 0.0
	snapshot_history.clear()
	has_snapshot_target = false
	velocity = Vector3.ZERO
	health = 100
	dead = false
	respawn_timer = 0.0
	crouched = false
	_select_weapon("px_9")
	_sync_active_weapon()

func mark_eliminated() -> void:
	dead = true
	health = 0
	velocity = Vector3.ZERO
	respawn_timer = RESPAWN_DELAY

func tick_respawn(delta: float, round_state: String, start_position: Vector3) -> void:
	if not dead or round_state != "LIVE":
		return
	respawn_timer = maxf(0.0, respawn_timer - maxf(delta, 0.0))
	if respawn_timer <= 0.0:
		begin_respawn(start_position)

func purchase_weapon(requested_id: String, round_state: String) -> bool:
	if dead or round_state != "BUY":
		return false
	var state := _weapon_state(requested_id)
	if state == null:
		return false
	if state.owned:
		return _select_weapon(requested_id)
	var root_cost := 0
	var definition_cost := 0
	var root := get_parent()
	if root != null:
		var catalog = root.get("weapons")
		if catalog is Array:
			for definition in catalog:
				if definition is Dictionary and str(definition.get("id", "")) == requested_id:
					definition_cost = int(definition.get("cost", 0))
					break
	root_cost = definition_cost
	if root_cost <= 0 or credits < root_cost:
		return false
	credits -= root_cost
	state.owned = true
	state.set_loaded_state(state.magazine_size, int(state.reserve_ammo))
	if requested_id == "ar_17":
		primary_owned = true
	_select_weapon(requested_id)
	return true

func reload_weapon(round_state: String) -> int:
	if dead or round_state != "LIVE":
		return 0
	var state := _weapon_state()
	if state == null:
		return 0
	var loaded := state.reload()
	_sync_active_weapon()
	return loaded

func apply_input(command: OpenStrikeInputCommand, delta: float, round_state: String = "LIVE") -> void:
	if command == null or dead:
		return

	last_processed_sequence = maxi(last_processed_sequence, command.sequence)
	for state in weapon_states.values():
		if state is OpenStrikeWeaponRuntimeState:
			state.tick(delta)

	if command.buy_weapon_id != "":
		purchase_weapon(command.buy_weapon_id, round_state)

	if command.switch_weapon:
		var requested := "ar_17" if weapon_id == "px_9" else "px_9"
		_select_weapon(requested)

	if command.weapon_id != "":
		_select_weapon(command.weapon_id)

	if command.reload:
		reload_weapon(round_state)

	_sync_active_weapon()
	yaw += command.look_delta.x * -0.0022
	pitch = clampf(pitch - command.look_delta.y * 0.0022, -1.45, 1.45)
	rotation.y = yaw

	var direction := (global_transform.basis * Vector3(command.move.x, 0.0, command.move.y)).normalized()
	var speed := CROUCH_SPEED if command.crouch else STAND_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 25.0 * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif command.jump and not command.crouch:
		velocity.y = 5.0

	crouched = command.crouch
	_update_collider()
	move_and_slide()

func can_fire() -> bool:
	var state := _weapon_state()
	return state != null and state.can_fire()

func consume_shot(fire_interval: float) -> bool:
	var state := _weapon_state()
	if state == null or not state.consume_shot(fire_interval):
		return false
	_sync_active_weapon()
	return true

func record_snapshot(tick: int) -> void:
	snapshot_history.push(tick, global_position, yaw, health)

func apply_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if snapshot == null:
		return
	if not snapshot_buffer.is_empty():
		var latest := snapshot_buffer[snapshot_buffer.size() - 1]
		if latest != null and snapshot.tick <= latest.tick:
			return

	var snap_distance := global_position.distance_to(snapshot.position)
	var hard_snap := not has_snapshot_target or snap_distance > 3.0 or snapshot.dead
	if hard_snap:
		global_position = snapshot.position
		rotation.y = snapshot.yaw
		pitch = snapshot.pitch
		snapshot_buffer.clear()
		snapshot_render_tick = float(snapshot.tick)

	snapshot_buffer.append(snapshot)
	if snapshot_buffer.size() > SNAPSHOT_BUFFER_MAX:
		snapshot_buffer.pop_front()

	snapshot_target_position = snapshot.position
	snapshot_target_yaw = snapshot.yaw
	snapshot_target_pitch = snapshot.pitch
	has_snapshot_target = true
	velocity = snapshot.velocity
	health = snapshot.health
	dead = snapshot.dead
	crouched = snapshot.crouched
	weapon_id = snapshot.weapon_id if not snapshot.weapon_id.is_empty() else weapon_id
	ammo = snapshot.ammo
	reserve = snapshot.reserve
	credits = snapshot.credits
	_update_collider()
	if hard_snap:
		yaw = snapshot.yaw
		pitch = snapshot.pitch
func make_snapshot(tick: int, round_state: String, round_number: int, objective_state: String, planted_site: String, bomb_time_left: float, carrier_peer_id_value: int = 0, dropped_bomb_position_value: Vector3 = Vector3.ZERO, round_won_value: bool = false, round_outcome_reason_value: String = "", objective_action_value: String = "", objective_action_peer_id_value: int = -1, objective_action_time_left_value: float = 0.0) -> OpenStrikeSnapshot:
	_sync_active_weapon()
	var snapshot := OpenStrikeSnapshot.new()
	snapshot.tick = tick
	snapshot.peer_id = peer_id
	snapshot.acknowledged_input_sequence = last_processed_sequence
	snapshot.position = global_position
	snapshot.velocity = velocity
	snapshot.yaw = yaw
	snapshot.pitch = pitch
	snapshot.weapon_id = weapon_id
	snapshot.ammo = ammo
	snapshot.reserve = reserve
	snapshot.credits = credits
	snapshot.owned_weapons.clear()
	for weapon_value in weapon_states.keys():
		var state = weapon_states.get(weapon_value)
		if state is OpenStrikeWeaponRuntimeState and state.owned:
			snapshot.owned_weapons.append(str(weapon_value))
	snapshot.health = health
	snapshot.dead = dead
	snapshot.crouched = crouched
	snapshot.round_state = round_state
	snapshot.round_number = round_number
	snapshot.round_won = round_won_value
	snapshot.round_outcome_reason = round_outcome_reason_value
	snapshot.objective_state = objective_state
	snapshot.planted_site = planted_site
	snapshot.bomb_time_left = bomb_time_left
	snapshot.carrier_peer_id = carrier_peer_id_value
	snapshot.dropped_bomb_position = dropped_bomb_position_value
	snapshot.objective_action = objective_action_value
	snapshot.objective_action_peer_id = objective_action_peer_id_value
	snapshot.objective_action_time_left = objective_action_time_left_value
	return snapshot

func _build_visual() -> void:
	if collision_shape != null:
		return
	collision_shape = CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = STAND_HEIGHT
	capsule_shape.radius = 0.35
	collision_shape.shape = capsule_shape
	add_child(collision_shape)

	visual_root = Node3D.new()
	visual_root.name = "RemoteAvatarVisual"
	add_child(visual_root)

	# Keep the capsule as the single collider, but give remote teammates a
	# readable low-poly tactical silhouette instead of a plain blue capsule.
	mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = STAND_HEIGHT
	capsule.radius = 0.35
	mesh.mesh = capsule
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.27, 0.40)
	body_material.roughness = 0.9
	mesh.material_override = body_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(mesh)

	var armor_material := StandardMaterial3D.new()
	armor_material.albedo_color = Color(0.075, 0.12, 0.16)
	armor_material.metallic = 0.08
	armor_material.roughness = 0.88
	var trim_material := StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.08, 0.48, 0.78)
	trim_material.emission_enabled = true
	trim_material.emission = Color(0.015, 0.12, 0.30)
	trim_material.emission_energy_multiplier = 0.45
	trim_material.roughness = 0.72
	var skin_material := StandardMaterial3D.new()
	skin_material.albedo_color = Color(0.43, 0.31, 0.23)
	skin_material.roughness = 0.96
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.025, 0.035, 0.045)
	dark_material.metallic = 0.18
	dark_material.roughness = 0.86

	_add_visual_box(Vector3(0.0, 0.02, -0.015), Vector3(0.56, 0.48, 0.34), armor_material)
	_add_visual_box(Vector3(0.0, 0.29, -0.205), Vector3(0.50, 0.12, 0.055), trim_material)
	_add_visual_box(Vector3(-0.34, 0.19, 0.0), Vector3(0.22, 0.24, 0.30), armor_material)
	_add_visual_box(Vector3(0.34, 0.19, 0.0), Vector3(0.22, 0.24, 0.30), armor_material)
	_add_visual_box(Vector3(-0.35, -0.16, -0.01), Vector3(0.16, 0.42, 0.18), dark_material)
	_add_visual_box(Vector3(0.35, -0.16, -0.01), Vector3(0.16, 0.42, 0.18), dark_material)
	_add_visual_box(Vector3(-0.16, -0.63, 0.015), Vector3(0.22, 0.42, 0.26), armor_material)
	_add_visual_box(Vector3(0.16, -0.63, 0.015), Vector3(0.22, 0.42, 0.26), armor_material)
	_add_visual_box(Vector3(0.0, 0.04, 0.235), Vector3(0.38, 0.46, 0.18), dark_material)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.62, 0.0)
	head.material_override = skin_material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(head)

	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.22
	helmet_mesh.height = 0.25
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.83, 0.0)
	helmet.material_override = armor_material
	helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(helmet)

	# A compact rifle silhouette points along the avatar's forward (-Z) axis.
	_add_visual_box(Vector3(0.20, -0.01, -0.34), Vector3(0.13, 0.12, 0.55), dark_material)
	_add_visual_box(Vector3(0.20, -0.02, -0.70), Vector3(0.055, 0.055, 0.28), armor_material)
	_add_visual_box(Vector3(0.20, -0.15, -0.27), Vector3(0.085, 0.20, 0.12), dark_material)

func _add_visual_box(box_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> void:
	var detail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	detail.mesh = box
	detail.position = box_position
	detail.material_override = material
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(detail)

func _update_collider() -> void:
	if collision_shape == null:
		return
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
