class_name OpenStrikeNetworkPlayer
extends CharacterBody3D

const GRAVITY := 14.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_SPEED := 5.6
const CROUCH_SPEED := 3.4

var peer_id: int = 0
var health: int = 100
var dead: bool = false
var crouched: bool = false
var yaw: float = 0.0
var pitch: float = 0.0
var last_processed_sequence: int = 0

var collision_shape: CollisionShape3D
var mesh: MeshInstance3D

func setup(id: int, start_position: Vector3) -> void:
	peer_id = id
	global_position = start_position
	yaw = rotation.y
	_build_visual()

func _build_visual() -> void:
	if collision_shape != null:
		return

	collision_shape = CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = STAND_HEIGHT
	capsule_shape.radius = 0.35
	collision_shape.shape = capsule_shape
	add_child(collision_shape)

	mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = STAND_HEIGHT
	capsule.radius = 0.35
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.45, 0.82)
	mesh.material_override = material
	add_child(mesh)

func apply_input(command: OpenStrikeInputCommand, delta: float) -> void:
	if command == null or dead:
		return

	last_processed_sequence = maxi(last_processed_sequence, command.sequence)
	yaw += command.look_delta.x * -0.0022
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

func apply_snapshot(snapshot: OpenStrikeSnapshot) -> void:
	if snapshot == null:
		return
	global_position = snapshot.position
	velocity = snapshot.velocity
	yaw = snapshot.yaw
	pitch = snapshot.pitch
	rotation.y = yaw
	health = snapshot.health
	dead = snapshot.dead
	last_processed_sequence = snapshot.acknowledged_input_sequence
	crouched = false
	_update_collider()

func make_snapshot(tick: int, round_state: String, round_number: int, objective_state: String, planted_site: String, bomb_time_left: float, weapon_id: String = "", ammo: int = 0, reserve: int = 0) -> OpenStrikeSnapshot:
	var snapshot := OpenStrikeSnapshot.new()
	snapshot.tick = tick
	snapshot.peer_id = peer_id
	snapshot.acknowledged_input_sequence = last_processed_sequence
	snapshot.position = global_position
	snapshot.velocity = velocity
	snapshot.yaw = yaw
	snapshot.pitch = pitch
	snapshot.health = health
	snapshot.dead = dead
	snapshot.round_state = round_state
	snapshot.round_number = round_number
	snapshot.objective_state = objective_state
	snapshot.planted_site = planted_site
	snapshot.bomb_time_left = bomb_time_left
	snapshot.weapon_id = weapon_id
	snapshot.ammo = ammo
	snapshot.reserve = reserve
	return snapshot

func _update_collider() -> void:
	if collision_shape == null:
		return
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
