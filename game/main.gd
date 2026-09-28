extends Node3D

const SPEED := 6.0
const JUMP := 5.0
const GRAVITY := 14.0
const SENS := 0.0022
const MAG := 30
const FIRE_DELAY := 0.095
const DAMAGE := 34

var player: CharacterBody3D
var camera: Camera3D
var pitch := 0.0
var ammo := MAG
var reserve := 90
var cooldown := 0.0
var hud: Label

func _ready() -> void:
    _world()
    _player()
    _hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.rotate_y(-event.relative.x * SENS)
        pitch = clamp(pitch - event.relative.y * SENS, -1.45, 1.45)
        camera.rotation.x = pitch
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
    player.velocity.x = move_toward(player.velocity.x, dir.x * SPEED, 25.0 * delta)
    player.velocity.z = move_toward(player.velocity.z, dir.z * SPEED, 25.0 * delta)
    if Input.is_action_just_pressed("jump") and player.is_on_floor():
        player.velocity.y = JUMP
    if Input.is_action_pressed("fire"):
        _fire()
    if Input.is_action_just_pressed("reload"):
        _reload()
    player.move_and_slide()
    hud.text = "HP 100    AMMO %02d / %02d\nWASD move   SPACE jump   LMB fire   R reload   ESC mouse" % [ammo, reserve]

func _fire() -> void:
    if cooldown > 0.0: return
    if ammo <= 0:
        _reload()
        return
    cooldown = FIRE_DELAY
    ammo -= 1
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 120.0)
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(DAMAGE)

func _reload() -> void:
    if ammo >= MAG or reserve <= 0: return
    var amount := mini(MAG - ammo, reserve)
    ammo += amount
    reserve -= amount

func _world() -> void:
    _box(Vector3(0,-0.5,0), Vector3(36,1,36), Color(0.18,0.20,0.23))
    _box(Vector3(0,2,-18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(0,2,18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(-18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    _box(Vector3(18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    for p in [Vector3(-7,1,-5),Vector3(6,1,-2),Vector3(-3,1,7),Vector3(10,1,9)]:
        _box(p, Vector3(3,2,2), Color(0.28,0.30,0.33))
    for p in [Vector3(-8,1,-12),Vector3(7,1,-9),Vector3(0,1,11)]:
        _target(p)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    var shape := CollisionShape3D.new()
    var collision := BoxShape3D.new()
    collision.size = size
    shape.shape = collision
    body.add_child(mesh)
    body.add_child(shape)
    add_child(body)

func _target(pos: Vector3) -> void:
    var body := StaticBody3D.new()
    body.set_script(load("res://target.gd"))
    body.position = pos
    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 2.0
    capsule.radius = 0.42
    mesh.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.75,0.20,0.16)
    mesh.material_override = mat
    var shape := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.height = 2.0
    capsule_shape.radius = 0.42
    shape.shape = capsule_shape
    body.add_child(mesh)
    body.add_child(shape)
    add_child(body)

func _player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,1.2,14)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.35
    shape.shape = capsule
    player.add_child(shape)
    camera = Camera3D.new()
    camera.position.y = 0.55
    camera.current = true
    player.add_child(camera)
    add_child(player)

func _hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24,24)
    hud.add_theme_font_size_override("font_size",20)
    layer.add_child(hud)
    var crosshair := Label.new()
    crosshair.text = "+"
    crosshair.position = Vector2(632,342)
    crosshair.add_theme_font_size_override("font_size",28)
    layer.add_child(crosshair)
