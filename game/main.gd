extends Node3D

const GRAVITY := 14.0
const SENS := 0.0022
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_CAMERA_Y := 0.55
const CROUCH_CAMERA_Y := 0.30
const MAX_HEALTH := 100
const ROUND_TIME := 120.0
const FREEZE_TIME := 3.0
const POST_ROUND_TIME := 2.5
const RESPAWN_DELAY := 2.0

const TEAM_BLUE := "BLUE"
const TEAM_RED := "RED"

var weapons := [
    {"name":"AR-17", "mag":30, "reserve":90, "damage":34, "delay":0.095, "recoil":0.018},
    {"name":"PX-9", "mag":12, "reserve":48, "damage":55, "delay":0.22, "recoil":0.028}
]

var weapon_index := 0
var ammo := 30
var reserve := 90
var player: CharacterBody3D
var player_shape: CollisionShape3D
var player_capsule: CapsuleShape3D
var camera: Camera3D
var pitch := 0.0
var cooldown := 0.0
var recoil_kick := 0.0
var crouched := false
var hud: Label

var player_team := TEAM_BLUE
var enemy_team := TEAM_RED
var health := MAX_HEALTH
var dead := false
var respawn_timer := 0.0

var round_number := 1
var round_state := "FREEZE"
var round_state_time_left := FREEZE_TIME
var round_time_left := ROUND_TIME
var enemies_alive := 0
var team_score := 0
var enemy_score := 0
var round_won := false

var blue_spawn_points := [
    Vector3(-6, 1.2, 14),
    Vector3(0, 1.2, 14),
    Vector3(6, 1.2, 14)
]

var red_spawn_points := [
    Vector3(-8, 1.0, -12),
    Vector3(7, 1.0, -9),
    Vector3(0, 1.0, 11)
]

func _ready() -> void:
    _world()
    _player()
    _hud()
    _start_round()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead:
        player.rotate_y(-event.relative.x * SENS)
        pitch = clamp(pitch - event.relative.y * SENS, -1.45, 1.45)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_E and not dead:
            _switch_weapon()
        elif event.keycode == KEY_R and not dead:
            _reload()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dead:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if dead:
        respawn_timer = maxf(0.0, respawn_timer - delta)
        if respawn_timer <= 0.0:
            _respawn_player()
        _update_hud()
        return

    _update_round_state(delta)
    if round_state != "LIVE":
        player.velocity.x = move_toward(player.velocity.x, 0.0, 25.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 25.0 * delta)
        player.move_and_slide()
        camera.rotation.x = pitch + recoil_kick
        _update_hud()
        return

    cooldown = maxf(0.0, cooldown - delta)
    recoil_kick = move_toward(recoil_kick, 0.0, delta * 0.20)

    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
    var move_speed := _current_speed()
    player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, 25.0 * delta)
    player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, 25.0 * delta)

    if Input.is_action_just_pressed("jump") and player.is_on_floor() and not crouched:
        player.velocity.y = 5.0

    var want_crouch := Input.is_action_pressed("crouch")
    if want_crouch != crouched:
        _set_crouch(want_crouch)

    if Input.is_action_pressed("fire"):
        _fire()
    if Input.is_action_just_pressed("reload"):
        _reload()

    player.move_and_slide()
    camera.rotation.x = pitch + recoil_kick
    _update_hud()

func _update_round_state(delta: float) -> void:
    round_state_time_left = maxf(0.0, round_state_time_left - delta)

    if round_state == "FREEZE":
        if round_state_time_left <= 0.0:
            round_state = "LIVE"
            round_state_time_left = ROUND_TIME
            round_time_left = ROUND_TIME
    elif round_state == "LIVE":
        round_time_left = maxf(0.0, round_time_left - delta)
        round_state_time_left = round_time_left
        if round_time_left <= 0.0:
            _finish_round(false)
    elif round_state == "POST":
        if round_state_time_left <= 0.0:
            round_number += 1
            _start_round()

func _current_weapon() -> Dictionary:
    return weapons[weapon_index]

func _current_speed() -> float:
    if crouched:
        return 2.8
    return 5.4 if weapon_index == 0 else 5.9

func _fire() -> void:
    if round_state != "LIVE" or cooldown > 0.0:
        return
    if ammo <= 0:
        _reload()
        return

    var weapon := _current_weapon()
    cooldown = float(weapon["delay"])
    ammo -= 1
    recoil_kick += float(weapon["recoil"])

    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)

    if hit and hit.collider.has_method("take_damage"):
        var target_team := str(hit.collider.get("team"))
        if target_team != player_team:
            hit.collider.take_damage(int(weapon["damage"]))
            if int(hit.collider.get("health")) <= 0:
                enemies_alive = maxi(0, enemies_alive - 1)
                if enemies_alive == 0:
                    _finish_round(true)

func _reload() -> void:
    if ammo >= int(_current_weapon()["mag"]) or reserve <= 0:
        return
    var magazine_size := int(_current_weapon()["mag"])
    var amount := mini(magazine_size - ammo, reserve)
    ammo += amount
    reserve -= amount

func _switch_weapon() -> void:
    _store_weapon_ammo()
    weapon_index = (weapon_index + 1) % weapons.size()
    _load_weapon_ammo()

func _store_weapon_ammo() -> void:
    weapons[weapon_index]["loaded"] = ammo
    weapons[weapon_index]["reserve_now"] = reserve

func _load_weapon_ammo() -> void:
    var weapon := _current_weapon()
    ammo = int(weapon.get("loaded", weapon["mag"]))
    reserve = int(weapon.get("reserve_now", weapon["reserve"]))

func _set_crouch(value: bool) -> void:
    crouched = value
    player_capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
    camera.position.y = CROUCH_CAMERA_Y if crouched else STAND_CAMERA_Y

func _update_hud() -> void:
    var weapon := _current_weapon()
    var state := "CROUCH" if crouched else "STAND"
    var phase := round_state
    if round_state == "POST":
        phase = "WON" if round_won else "LOST"
    var phase_time := round_state_time_left if round_state != "LIVE" else round_time_left

    if dead:
        hud.text = "ROUND %02d  %s\nYOU ARE DOWN — RESPAWNING %0.1fs" % [round_number, phase, respawn_timer]
        return

    hud.text = "ROUND %02d  %s  %03d\nTEAM %s  %02d - %02d  %s    %s    AMMO %02d / %02d\nHP %03d    ENEMIES %02d\nWASD move   CTRL crouch   SPACE jump   LMB fire   R reload   E switch   ESC mouse" % [
        round_number, phase, ceili(phase_time), player_team, team_score, enemy_score,
        weapon["name"], state, ammo, reserve, health, enemies_alive
    ]

func _start_round() -> void:
    _reset_targets()
    _spawn_player()
    round_state = "FREEZE"
    round_state_time_left = FREEZE_TIME
    round_time_left = ROUND_TIME
    health = MAX_HEALTH
    dead = false
    respawn_timer = 0.0
    round_won = false

func _finish_round(won: bool) -> void:
    if round_state != "LIVE":
        return
    round_state = "POST"
    round_state_time_left = POST_ROUND_TIME
    round_won = won
    if won:
        team_score += 1
    else:
        enemy_score += 1

func _reset_targets() -> void:
    var count := 0
    for child in get_children():
        if child.has_method("reset_target"):
            child.reset_target()
            count += 1
    enemies_alive = count

func _spawn_player() -> void:
    var spawn_index := (round_number - 1) % blue_spawn_points.size()
    player.global_position = blue_spawn_points[spawn_index]
    player.velocity = Vector3.ZERO
    player.rotation.y = 0.0
    pitch = 0.0
    _set_crouch(false)
    player.visible = true
    camera.current = true

func _apply_damage(amount: int) -> void:
    if dead or round_state != "LIVE":
        return
    health = maxi(0, health - amount)
    if health == 0:
        _kill_player()

func _kill_player() -> void:
    dead = true
    respawn_timer = RESPAWN_DELAY
    player.visible = false
    camera.current = false

func _respawn_player() -> void:
    dead = false
    health = MAX_HEALTH
    _spawn_player()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _world() -> void:
    _box(Vector3(0,-0.5,0), Vector3(36,1,36), Color(0.18,0.20,0.23))
    _box(Vector3(0,2,-18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(0,2,18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(-18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    _box(Vector3(18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    for p in [Vector3(-7,1,-5), Vector3(6,1,-2), Vector3(-3,1,7), Vector3(10,1,9)]:
        _box(p, Vector3(3,2,2), Color(0.28,0.30,0.33))
    for i in red_spawn_points.size():
        _target(red_spawn_points[i])

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
    body.set("team", enemy_team)
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
    player.position = blue_spawn_points[1]
    player_shape = CollisionShape3D.new()
    player_capsule = CapsuleShape3D.new()
    player_capsule.height = STAND_HEIGHT
    player_capsule.radius = 0.35
    player_shape.shape = player_capsule
    player.add_child(player_shape)

    camera = Camera3D.new()
    camera.position.y = STAND_CAMERA_Y
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
