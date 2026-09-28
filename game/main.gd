extends Node3D

const GRAVITY := 14.0
const SENS := 0.0022
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_CAMERA_Y := 0.55
const CROUCH_CAMERA_Y := 0.30
const MAX_HEALTH := 100
const ROUND_TIME := 120.0
const BUY_TIME := 10.0
const POST_ROUND_TIME := 2.5
const STARTING_CREDITS := 1200
const ROUND_WIN_REWARD := 2200
const ROUND_LOSS_REWARD := 1200
const KILL_REWARD := 300
const MAX_CREDITS := 16000
const RESPAWN_DELAY := 2.0
const PLANT_TIME := 2.5
const DEFUSE_TIME := 4.0
const BOMB_TIME := 30.0
const BOMB_SITE_RADIUS := 2.8
const BOMB_PICKUP_RADIUS := 1.6

const BOMB_SITE_A := Vector3(-10, 0.15, -7)
const BOMB_SITE_B := Vector3(10, 0.15, 7)
const BOT_COUNT := 3

const TEAM_BLUE := "BLUE"
const TEAM_RED := "RED"

var weapons := [
    {"name":"AR-17", "mag":30, "reserve":90, "damage":34, "delay":0.095, "recoil":0.018, "cost":2400},
    {"name":"PX-9", "mag":12, "reserve":48, "damage":55, "delay":0.22, "recoil":0.028, "cost":700}
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
var bomb_site_a := BOMB_SITE_A
var bomb_site_b := BOMB_SITE_B
var health := MAX_HEALTH
var dead := false
var respawn_timer := 0.0

var round_number := 1
var round_state := "BUY"
var round_state_time_left := BUY_TIME
var round_time_left := ROUND_TIME
var enemies_alive := 0
var team_score := 0
var enemy_score := 0
var round_won := false
var credits := STARTING_CREDITS
var primary_owned := false

var objective_state := "CARRIED"
var objective_site := ""
var planted_site := ""
var dropped_bomb_position := Vector3.ZERO
var bomb_visual: MeshInstance3D
var bomb_light: OmniLight3D
var bomb_time_left := 0.0
var objective_action := ""
var objective_action_time_left := 0.0
var bot_defuse_time_left := 0.0
var active_defuser: Node = null
var bomb_defense_revision := 0
var bots: Array[CharacterBody3D] = []
var navigation_points: Array[Vector3] = []
var cover_points: Array[Dictionary] = []
var bomb_cover_anchors: Array[Dictionary] = []

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
    bomb_site_a = BOMB_SITE_A
    bomb_site_b = BOMB_SITE_B
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
        elif event.keycode == KEY_1 and not dead:
            _buy_weapon(0)
        elif event.keycode == KEY_2 and not dead:
            _buy_weapon(1)
        elif event.keycode == KEY_E and not dead:
            _switch_weapon()
        elif event.keycode == KEY_R and not dead:
            _reload()
        elif event.keycode == KEY_F and not dead:
            _begin_objective_action()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dead:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    _update_bomb_visual()
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

    _update_bots(delta)
    _update_objective(delta)
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

    if round_state == "BUY":
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

func _current_bomb_site() -> String:
    if player.global_position.distance_to(BOMB_SITE_A) <= BOMB_SITE_RADIUS:
        return "A"
    if player.global_position.distance_to(BOMB_SITE_B) <= BOMB_SITE_RADIUS:
        return "B"
    return ""


func _begin_objective_action() -> void:
    if round_state != "LIVE" or objective_action != "":
        return

    if objective_state == "CARRIED":
        var site := _current_bomb_site()
        if site != "":
            objective_site = site
            objective_action = "PLANT"
            objective_action_time_left = PLANT_TIME
    elif objective_state == "DROPPED":
        if player.global_position.distance_to(dropped_bomb_position) <= BOMB_PICKUP_RADIUS:
            objective_state = "CARRIED"
            objective_site = ""
            dropped_bomb_position = Vector3.ZERO
    elif objective_state == "PLANTED":
        var site := _current_bomb_site()
        if site == planted_site:
            objective_site = site
            objective_action = "DEFUSE"
            objective_action_time_left = DEFUSE_TIME


func _update_objective(delta: float) -> void:
    if round_state != "LIVE":
        objective_action = ""
        objective_action_time_left = 0.0
        return

    var site := _current_bomb_site()

    if objective_state == "CARRIED":
        if objective_action == "PLANT":
            if site == "" or site != objective_site or not Input.is_key_pressed(KEY_F):
                objective_action = ""
                objective_action_time_left = 0.0
            else:
                objective_action_time_left = maxf(0.0, objective_action_time_left - delta)
                if objective_action_time_left <= 0.0:
                    objective_state = "PLANTED"
                    planted_site = site
                    bomb_time_left = BOMB_TIME
                    objective_action = ""
                    objective_action_time_left = 0.0
    elif objective_state == "DROPPED":
        if player.global_position.distance_to(dropped_bomb_position) <= BOMB_SITE_RADIUS:
            objective_site = "NEAR"
        else:
            objective_site = ""
    elif objective_state == "PLANTED":
        objective_site = planted_site
        bomb_time_left = maxf(0.0, bomb_time_left - delta)
        _update_bot_defuse(delta)

        if bomb_time_left <= 0.0:
            objective_state = "EXPLODED"
            _finish_round(true)
            return

        if objective_action == "DEFUSE":
            if site != planted_site or not Input.is_key_pressed(KEY_F):
                objective_action = ""
                objective_action_time_left = 0.0
            else:
                objective_action_time_left = maxf(0.0, objective_action_time_left - delta)
                if objective_action_time_left <= 0.0:
                    objective_state = "DEFUSED"
                    objective_action = ""
                    objective_action_time_left = 0.0
                    _finish_round(false)

func _update_bot_defuse(delta: float) -> void:
    if objective_action == "DEFUSE":
        return

    var site_position := bomb_site_a if planted_site == "A" else bomb_site_b
    if not is_instance_valid(active_defuser) or active_defuser.dead:
        active_defuser = null
        bot_defuse_time_left = 0.0

    if active_defuser == null:
        var previous_defuser: Node = active_defuser
        var nearest_bot: Node = null
        var nearest_distance := INF
        for bot in bots:
            if not is_instance_valid(bot) or bot.dead:
                continue
            var distance := bot.global_position.distance_to(site_position)
            if distance < nearest_distance:
                nearest_distance = distance
                nearest_bot = bot

        if nearest_bot != null:
            active_defuser = nearest_bot
            bot_defuse_time_left = DEFUSE_TIME
            if active_defuser != previous_defuser:
                bomb_defense_revision += 1

    if active_defuser != null:
        var defuser_distance := active_defuser.global_position.distance_to(site_position)
        if defuser_distance <= BOMB_SITE_RADIUS:
            bot_defuse_time_left = maxf(0.0, bot_defuse_time_left - delta)
            if bot_defuse_time_left <= 0.0:
                objective_state = "DEFUSED"
                _finish_round(false)


func _update_bomb_visual() -> void:
    if bomb_visual == null:
        return

    var visible_bomb := objective_state == "DROPPED" or objective_state == "PLANTED"
    bomb_visual.visible = visible_bomb
    if bomb_light != null:
        bomb_light.visible = visible_bomb

    if not visible_bomb:
        return

    var bomb_position := dropped_bomb_position
    if objective_state == "PLANTED":
        bomb_position = bomb_site_a if planted_site == "A" else bomb_site_b

    bomb_visual.global_position = bomb_position + Vector3(0, 0.35, 0)
    var blink_phase := fmod(Time.get_ticks_msec() / 1000.0, 1.0)
    var active_blink := blink_phase < 0.5 if objective_state == "PLANTED" else true
    if bomb_light != null:
        bomb_light.light_energy = 2.5 if active_blink else 0.35

func _objective_label() -> String:
    if objective_state == "CARRIED":
        if objective_action == "PLANT":
            return "BOMB: PLANTING %s %0.1fs" % [objective_site, objective_action_time_left]
        if objective_site != "":
            return "BOMB: CARRIED — SITE %s — HOLD F" % objective_site
        return "BOMB: CARRIED — MOVE TO A/B"
    if objective_state == "DROPPED":
        if objective_site == "NEAR":
            return "BOMB: DROPPED — HOLD F TO RECOVER"
        return "BOMB: DROPPED — RECOVER AT %0.1f, %0.1f" % [dropped_bomb_position.x, dropped_bomb_position.z]
    if objective_state == "PLANTED":
        if objective_action == "DEFUSE":
            return "BOMB: PLANTED %s — DEFUSING %0.1fs" % [planted_site, objective_action_time_left]
        return "BOMB: PLANTED %s — %0.1fs" % [planted_site, bomb_time_left]
    if objective_state == "DEFUSED":
        return "BOMB: DEFUSED"
    if objective_state == "EXPLODED":
        return "BOMB: EXPLODED"
    return "BOMB: NONE"


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
                credits = mini(MAX_CREDITS, credits + KILL_REWARD)
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
    if not primary_owned:
        weapon_index = 1
        _load_weapon_ammo()
        return
    _store_weapon_ammo()
    weapon_index = (weapon_index + 1) % weapons.size()
    _load_weapon_ammo()

func _buy_weapon(index: int) -> void:
    if dead or round_state != "BUY":
        return
    if index == 0:
        if primary_owned:
            weapon_index = 0
            _load_weapon_ammo()
            return
        var primary := weapons[0]
        var cost := int(primary["cost"])
        if credits < cost:
            return
        credits -= cost
        primary_owned = true
        weapon_index = 0
        ammo = int(primary["mag"])
        reserve = int(primary["reserve"])
        cooldown = 0.0
    elif index == 1:
        weapon_index = 1
        ammo = int(weapons[1]["mag"])
        reserve = int(weapons[1]["reserve"])
        cooldown = 0.0

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

    var buy_line := ""
    if round_state == "BUY":
        buy_line = "BUY: [1] %s $%d   [2] %s $%d" % [
            weapons[0]["name"], weapons[0]["cost"], weapons[1]["name"], weapons[1]["cost"]
        ]

    hud.text = "ROUND %02d  %s  %03d\nTEAM %s  %02d - %02d    CREDITS $%04d\n%s\n%s\n%s    %s    AMMO %02d / %02d\nHP %03d    ENEMIES %02d\nWASD move   CTRL crouch   SPACE jump   LMB fire   R reload   E switch   F objective   ESC mouse" % [
        round_number, phase, ceili(phase_time), player_team, team_score, enemy_score,
        credits, buy_line, _objective_label(), weapon["name"], state, ammo, reserve, health, enemies_alive
    ]

func _start_round() -> void:
    _reset_targets()
    primary_owned = false
    weapon_index = 1
    ammo = int(weapons[1]["mag"])
    reserve = int(weapons[1]["reserve"])
    cooldown = 0.0
    _spawn_player()
    round_state = "BUY"
    round_state_time_left = BUY_TIME
    round_time_left = ROUND_TIME
    health = MAX_HEALTH
    dead = false
    respawn_timer = 0.0
    round_won = false
    objective_state = "CARRIED"
    objective_site = ""
    planted_site = ""
    bomb_time_left = 0.0
    objective_action = ""
    objective_action_time_left = 0.0
    bot_defuse_time_left = 0.0
    active_defuser = null
    bomb_defense_revision += 1
    dropped_bomb_position = Vector3.ZERO

func _finish_round(won: bool) -> void:
    if round_state != "LIVE":
        return
    round_state = "POST"
    round_state_time_left = POST_ROUND_TIME
    round_won = won
    if won:
        team_score += 1
        credits = mini(MAX_CREDITS, credits + ROUND_WIN_REWARD)
    else:
        enemy_score += 1
        credits = mini(MAX_CREDITS, credits + ROUND_LOSS_REWARD)

func _reset_targets() -> void:
    var count := 0
    for bot in bots:
        if is_instance_valid(bot):
            bot.reset_target()
            count += 1
    enemies_alive = count

func _update_bots(delta: float) -> void:
    if round_state != "LIVE":
        return
    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            bot.process_mode = Node.PROCESS_MODE_INHERIT

func _on_enemy_eliminated(bot: Node) -> void:
    enemies_alive = maxi(0, enemies_alive - 1)
    credits = mini(MAX_CREDITS, credits + KILL_REWARD)
    if enemies_alive == 0:
        _finish_round(true)

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
    if objective_state == "CARRIED":
        objective_state = "DROPPED"
        dropped_bomb_position = player.global_position + Vector3(0, 0.15, 0)
        objective_site = ""
        objective_action = ""
        objective_action_time_left = 0.0
        _update_bomb_visual()
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
    _setup_navigation_points()
    _setup_cover_points()
    _spawn_bots()
    _objective_site(BOMB_SITE_A, "A")
    _objective_site(BOMB_SITE_B, "B")
    _create_bomb_visual()

func _create_bomb_visual() -> void:
    bomb_visual = MeshInstance3D.new()
    bomb_visual.name = "BombVisual"
    var bomb_mesh := BoxMesh.new()
    bomb_mesh.size = Vector3(0.65, 0.35, 0.45)
    bomb_visual.mesh = bomb_mesh

    var bomb_material := StandardMaterial3D.new()
    bomb_material.albedo_color = Color(0.08, 0.09, 0.11, 1.0)
    bomb_material.metallic = 0.25
    bomb_material.roughness = 0.45
    bomb_material.emission_enabled = true
    bomb_material.emission = Color(0.9, 0.18, 0.08, 1.0)
    bomb_material.emission_energy_multiplier = 0.8
    bomb_visual.material_override = bomb_material
    bomb_visual.visible = false
    add_child(bomb_visual)

    bomb_light = OmniLight3D.new()
    bomb_light.name = "BombLight"
    bomb_light.light_color = Color(1.0, 0.2, 0.08, 1.0)
    bomb_light.omni_range = 3.5
    bomb_light.light_energy = 2.5
    bomb_light.visible = false
    bomb_visual.add_child(bomb_light)

func _objective_site(pos: Vector3, label: String) -> void:
    var marker := MeshInstance3D.new()
    marker.position = pos
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = BOMB_SITE_RADIUS
    cylinder.bottom_radius = BOMB_SITE_RADIUS
    cylinder.height = 0.08
    marker.mesh = cylinder
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.55, 0.90, 0.45)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker.material_override = mat
    add_child(marker)

    var site_label := Label3D.new()
    site_label.text = "SITE " + label
    site_label.position = pos + Vector3(0, 0.35, 0)
    site_label.font_size = 48
    site_label.outline_size = 8
    add_child(site_label)


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

func _setup_navigation_points() -> void:
    navigation_points = [
        Vector3(-13, 1.0, -13),
        Vector3(-13, 1.0, 0),
        Vector3(-13, 1.0, 13),
        Vector3(-4, 1.0, -13),
        Vector3(-4, 1.0, 0),
        Vector3(-4, 1.0, 13),
        Vector3(5, 1.0, -13),
        Vector3(5, 1.0, 0),
        Vector3(5, 1.0, 13),
        Vector3(13, 1.0, -13),
        Vector3(13, 1.0, 0),
        Vector3(13, 1.0, 13)
    ]

func _navigation_visible(from: Vector3, to: Vector3) -> bool:
    var start := from + Vector3(0, 0.15, 0)
    var end := to + Vector3(0, 0.15, 0)
    var query := PhysicsRayQueryParameters3D.create(start, end)
    var excluded: Array[Node3D] = [player]
    for bot in bots:
        if is_instance_valid(bot):
            excluded.append(bot)
    query.exclude = excluded
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty()

func _find_navigation_route(start: Vector3, goal: Vector3) -> Array:
    var points: Array = navigation_points
    if points.is_empty():
        return [goal]

    var start_index := -1
    var goal_index := -1
    var start_distance := INF
    var goal_distance := INF

    for i in points.size():
        var start_dist := points[i].distance_to(start)
        if start_dist < start_distance and _navigation_visible(start, points[i]):
            start_distance = start_dist
            start_index = i

        var goal_dist := points[i].distance_to(goal)
        if goal_dist < goal_distance and _navigation_visible(points[i], goal):
            goal_distance = goal_dist
            goal_index = i

    if start_index < 0 or goal_index < 0:
        return [goal]

    var queue: Array[int] = [start_index]
    var visited := {}
    var previous := {}
    visited[start_index] = true

    while not queue.is_empty():
        var current: int = queue.pop_front()
        if current == goal_index:
            break

        for neighbor in points.size():
            if neighbor == current or visited.has(neighbor):
                continue
            if not _navigation_visible(points[current], points[neighbor]):
                continue
            visited[neighbor] = true
            previous[neighbor] = current
            queue.append(neighbor)

    if not visited.has(goal_index):
        return [points[start_index], goal]

    var indices: Array[int] = []
    var cursor := goal_index
    while true:
        indices.push_front(cursor)
        if cursor == start_index:
            break
        cursor = int(previous[cursor])

    var route: Array = []
    for index in indices:
        route.append(points[index])
    if route.is_empty() or route[route.size() - 1].distance_to(goal) > WAYPOINT_REACHED:
        route.append(goal)
    return route

func _has_obstacle_between(from: Vector3, to: Vector3) -> bool:
    var start := from + Vector3(0, 0.9, 0)
    var end := to + Vector3(0, 0.9, 0)
    var query := PhysicsRayQueryParameters3D.create(start, end)
    var excluded: Array[Node3D] = [player]
    for bot in bots:
        if is_instance_valid(bot):
            excluded.append(bot)
    query.exclude = excluded
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty()

func _select_bot_bomb_cover(site_position: Vector3, player_position: Vector3, bot: Node) -> Vector3:
    var best := Vector3.ZERO
    var best_score := INF
    var candidates: Array = []

    for data in bomb_cover_anchors:
        if str(data["site"]) == str(planted_site):
            candidates.append(data)

    for data in cover_points:
        candidates.append({"site": "", "cover": data["cover"], "peek": data["peek"]})

    for data in candidates:
        var cover_position: Vector3 = data["cover"]
        var peek_position: Vector3 = data["peek"]
        var site_distance := cover_position.distance_to(site_position)
        if site_distance > 10.0:
            continue
        var player_distance := cover_position.distance_to(player_position)
        if player_distance < 6.0:
            continue
        if not _has_obstacle_between(player_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if _has_obstacle_between(peek_position, player_position + Vector3(0, 1.0, 0)):
            continue

        var occupied := false
        for other in bots:
            if other == bot or not is_instance_valid(other) or other.dead:
                continue
            if other.global_position.distance_to(cover_position) < 2.5:
                occupied = true
                break
            if str(other.state) == "BOMB_COVER" and other.current_goal.distance_to(cover_position) < 2.5:
                occupied = true
                break
        if occupied:
            continue

        var bot_distance := bot.global_position.distance_to(cover_position)
        var anchor_bonus := -1.0 if str(data["site"]) == str(planted_site) else 0.0
        var score := site_distance * 1.15 + absf(player_distance - 14.0) * 0.22 + bot_distance * 0.18 + anchor_bonus
        if score < best_score:
            best_score = score
            best = cover_position

    return best

func _select_bot_attack_position(bot: Node, player_position: Vector3, slot: int) -> Vector3:
    var best := Vector3.ZERO
    var best_score := INF
    var player_to_bot := bot.global_position - player_position
    player_to_bot.y = 0.0
    if player_to_bot.length() < 0.1:
        player_to_bot = Vector3(0, 0, 1)
    var forward := player_to_bot.normalized()
    var side := Vector3(-forward.z, 0.0, forward.x)
    var target_side := -1.0 if slot == 0 else (1.0 if slot == 1 else 0.0)

    for i in cover_points.size():
        var data: Dictionary = cover_points[i]
        var cover_position: Vector3 = data["cover"]
        var peek_position: Vector3 = data["peek"]
        var player_distance := peek_position.distance_to(player_position)
        var bot_distance := bot.global_position.distance_to(peek_position)
        if player_distance < 8.0 or player_distance > 20.0 or bot_distance > 20.0:
            continue
        if not _has_obstacle_between(player_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if _has_obstacle_between(peek_position, player_position + Vector3(0, 1.0, 0)):
            continue

        var occupied := false
        for other in bots:
            if other == bot or not is_instance_valid(other) or other.dead:
                continue
            if other.global_position.distance_to(peek_position) < 3.0:
                occupied = true
                break
            if (str(other.state) == "REPOSITION" or str(other.state) == "ATTACK" or str(other.state) == "PEEK") and other.current_goal.distance_to(peek_position) < 3.0:
                occupied = true
                break
        if occupied:
            continue

        var from_player := peek_position - player_position
        from_player.y = 0.0
        if from_player.length() < 0.1:
            continue
        var lateral := absf(from_player.normalized().dot(side))
        var forward_alignment := from_player.normalized().dot(forward)
        var slot_score := absf(lateral - (0.85 if target_side != 0.0 else 0.35))
        if target_side != 0.0:
            slot_score += maxf(0.0, -forward_alignment) * 0.25
        else:
            slot_score += absf(forward_alignment) * 0.12

        var score := bot_distance * 0.25 + absf(player_distance - 14.0) * 0.45 + slot_score * 4.0
        if score < best_score:
            best_score = score
            best = peek_position

    return best

func _select_bot_combat_cover(bot: Node, player_position: Vector3, preferred_distance: float) -> Vector3:
    var best := Vector3.ZERO
    var best_score := INF
    for data in cover_points:
        var cover_position: Vector3 = data["cover"]
        var peek_position: Vector3 = data["peek"]
        var bot_distance := bot.global_position.distance_to(cover_position)
        if bot_distance > 20.0:
            continue
        var player_distance := cover_position.distance_to(player_position)
        if player_distance < 6.0:
            continue
        if not _has_obstacle_between(player_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if _has_obstacle_between(peek_position, player_position + Vector3(0, 1.0, 0)):
            continue

        var occupied := false
        for other in bots:
            if other == bot or not is_instance_valid(other) or other.dead:
                continue
            if other.global_position.distance_to(cover_position) < 2.5:
                occupied = true
                break
            if (str(other.state) == "COVER" or str(other.state) == "PEEK") and other.current_goal.distance_to(cover_position) < 2.5:
                occupied = true
                break
        if occupied:
            continue

        var score := bot_distance * 0.35 + absf(player_distance - preferred_distance) * 0.75
        if str(bot.role) == "ROAMER":
            score -= minf(player_distance, 18.0) * 0.04
        if score < best_score:
            best_score = score
            best = cover_position
    return best

func _select_bot_site_cover(site_position: Vector3, player_position: Vector3, role: String) -> Vector3:
    var best := Vector3.ZERO
    var best_score := INF
    var candidates: Array = []

    for data in bomb_cover_anchors:
        if str(data["site"]) == ("A" if site_position == bomb_site_a else "B"):
            candidates.append(data)

    for data in cover_points:
        candidates.append({"site": "", "cover": data["cover"], "peek": data["peek"]})

    var player_from_site := player_position - site_position
    player_from_site.y = 0.0

    for data in candidates:
        var cover_position: Vector3 = data["cover"]
        var peek_position: Vector3 = data["peek"]
        var site_distance := cover_position.distance_to(site_position)
        if site_distance > 10.0:
            continue

        var player_distance := cover_position.distance_to(player_position)
        if player_distance < 5.0:
            continue
        if not _has_obstacle_between(player_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if _has_obstacle_between(peek_position, player_position + Vector3(0, 1.0, 0)):
            continue

        var occupied := false
        for other in bots:
            if not is_instance_valid(other) or other.dead:
                continue
            if str(other.role) == role:
                continue
            if other.global_position.distance_to(cover_position) < 2.5:
                occupied = true
                break
            if str(other.state) == "BOMB_COVER" and other.current_goal.distance_to(cover_position) < 2.5:
                occupied = true
                break
        if occupied:
            continue

        var cover_from_site := cover_position - site_position
        cover_from_site.y = 0.0
        var angle_alignment := 0.0
        if player_from_site.length() > 0.1 and cover_from_site.length() > 0.1:
            angle_alignment = cover_from_site.normalized().dot(player_from_site.normalized())

        var role_bias := 0.0
        if role == "ROAMER":
            role_bias = absf(angle_alignment) * 1.4
        elif role == "DEFENDER_A" or role == "DEFENDER_B":
            role_bias = -angle_alignment * 1.8

        var anchor_bonus := -1.5 if str(data["site"]) != "" else 0.0
        var score := site_distance * 1.25 + absf(player_distance - 14.0) * 0.25 + role_bias + anchor_bonus
        if score < best_score:
            best_score = score
            best = cover_position

    return best

func _setup_cover_points() -> void:
    cover_points = [
        {"cover": Vector3(-9.0, 1.0, -5.0), "peek": Vector3(-7.2, 1.0, -3.6)},
        {"cover": Vector3(4.0, 1.0, -3.0), "peek": Vector3(5.8, 1.0, -1.7)},
        {"cover": Vector3(-5.0, 1.0, 6.0), "peek": Vector3(-3.2, 1.0, 7.4)},
        {"cover": Vector3(8.0, 1.0, 8.0), "peek": Vector3(9.8, 1.0, 9.2)}
    ]
    bomb_cover_anchors = [
        {"site": "A", "cover": Vector3(-9.0, 1.0, -5.0), "peek": Vector3(-7.2, 1.0, -3.6)},
        {"site": "A", "cover": Vector3(-5.0, 1.0, 6.0), "peek": Vector3(-3.2, 1.0, 7.4)},
        {"site": "B", "cover": Vector3(4.0, 1.0, -3.0), "peek": Vector3(5.8, 1.0, -1.7)},
        {"site": "B", "cover": Vector3(8.0, 1.0, 8.0), "peek": Vector3(9.8, 1.0, 9.2)}
    ]

func _spawn_bots() -> void:
    bots.clear()
    for i in BOT_COUNT:
        var bot := CharacterBody3D.new()
        bot.set_script(load("res://bot.gd"))
        bot.position = red_spawn_points[i % red_spawn_points.size()]
        bot.set("team", enemy_team)
        bot.set("role", "DEFENDER_A" if i == 0 else ("DEFENDER_B" if i == 1 else "ROAMER"))
        bot.set("combat_slot", i)

        var mesh := MeshInstance3D.new()
        var capsule := CapsuleMesh.new()
        capsule.height = 2.0
        capsule.radius = 0.42
        mesh.mesh = capsule
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.75, 0.20, 0.16)
        mesh.material_override = mat

        var shape := CollisionShape3D.new()
        var capsule_shape := CapsuleShape3D.new()
        capsule_shape.height = 2.0
        capsule_shape.radius = 0.42
        shape.shape = capsule_shape

        bot.add_child(mesh)
        bot.add_child(shape)
        bot.add_to_group("bots")
        add_child(bot)
        bot.eliminated.connect(_on_enemy_eliminated)
        bots.append(bot)

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
