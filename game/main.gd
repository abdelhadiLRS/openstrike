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
const COMBAT_SLOT_UPDATE_INTERVAL := 0.75
const COMBAT_ASSIGNMENT_UPDATE_INTERVAL := 1.25
const TACTICAL_MEMORY_TIMEOUT := 4.5
const TACTICAL_MEMORY_MIN_UPDATE := 0.35
const CONTACT_MEMORY_TIMEOUT := 4.0
const CONTACT_UPDATE_INTERVAL := 0.25
const TACTICAL_MEMORY_MAX_DISTANCE := 34.0
const SQUAD_SEARCH_DURATION := 6.0
const SQUAD_SEARCH_UPDATE_INTERVAL := 0.75
const SQUAD_SEARCH_SECTOR_RADIUS := 5.5
const SQUAD_SEARCH_FORWARD_STEP := 3.5
const COMBAT_DIRECTOR_UPDATE_INTERVAL := 0.20
const COMBAT_SUPPORT_DELAY := 0.35
const COMBAT_FLANK_DELAY := 0.70
const THREAT_CONTACT_TIMEOUT := 0.9
const THREAT_TRACKED_TIMEOUT := 4.5
const THREAT_SEARCH_TIMEOUT := 6.0

const TEAM_BLUE := "BLUE"
const TEAM_RED := "RED"

var weapons := [
    {"name":"AR-17", "mag":30, "reserve":90, "damage":34, "delay":0.095, "recoil":0.018, "cost":2400},
    {"name":"PX-9", "mag":12, "reserve":48, "damage":55, "delay":0.22, "recoil":0.028, "cost":0}
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
var navigation_graph: Array[Array] = []
var cover_points: Array[Dictionary] = []
var bomb_cover_anchors: Array[Dictionary] = []
var combat_slot_update_timer := 0.0
var combat_assignment_update_timer := 0.0
var combat_engagement_revision := 0
var combat_role_revision := 0
var combat_assignment_contact_revision := -1
var combat_assignment_threat_revision := -1
var combat_assignment_objective_state := ""
var combat_assignment_objective_site := ""
var combat_assignment_dropped_position := Vector3.ZERO
var tactical_memory_position := Vector3.ZERO
var tactical_memory_timer := 0.0
var tactical_memory_revision := 0
var squad_contact_position := Vector3.ZERO
var squad_contact_timer := 0.0
var squad_contact_revision := 0
var squad_contact_source: Node = null
var squad_contact_update_timer := 0.0
var last_known_player_position := Vector3.ZERO
var last_known_player_timer := 0.0
var squad_search_active := false
var squad_search_timer := 0.0
var squad_search_update_timer := 0.0
var squad_search_revision := 0
var squad_search_cycle := 0
var combat_director_phase := "IDLE"
var combat_director_timer := 0.0
var combat_director_revision := 0
var combat_director_contact_revision := -1
var combat_director_threat_revision := -1
var combat_contact_started_at := 0
var squad_threat_state := "LOST"
var squad_threat_position := Vector3.ZERO
var squad_threat_timer := 0.0
var squad_threat_revision := 0

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

    _update_tactical_memory(delta)
    _update_squad_threat(delta)
    _update_combat_director(delta)
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
        if round_time_left <= 0.0 and objective_state != "PLANTED":
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

func _bot_has_navigation_path(bot: Node, goal: Vector3) -> bool:
    if not is_instance_valid(bot) or bot.dead:
        return false

    if navigation_points.is_empty():
        return true

    if navigation_graph.size() != navigation_points.size():
        _build_navigation_graph()

    var start_index := _find_nearest_navigation_point(bot.global_position)
    var goal_index := _find_nearest_navigation_point(goal)
    if start_index < 0 or goal_index < 0:
        return false
    if start_index == goal_index:
        return true

    var open_set: Array[int] = [start_index]
    var visited := {start_index: true}
    while not open_set.is_empty():
        var current: int = open_set.pop_front()
        for neighbor_value in navigation_graph[current]:
            var neighbor: int = int(neighbor_value)
            if neighbor == goal_index:
                return true
            if visited.has(neighbor):
                continue
            visited[neighbor] = true
            open_set.append(neighbor)

    return false


func _update_bot_defuse(delta: float) -> void:
    if objective_action == "DEFUSE":
        return

    var site_position := bomb_site_a if planted_site == "A" else bomb_site_b
    if not is_instance_valid(active_defuser) or active_defuser.dead:
        active_defuser = null
        bot_defuse_time_left = 0.0

    if active_defuser != null:
        var defuser_distance := active_defuser.global_position.distance_to(site_position)
        if defuser_distance > BOMB_SITE_RADIUS:
            active_defuser = null
            bot_defuse_time_left = 0.0
            bomb_defense_revision += 1

    if active_defuser == null:
        var nearest_bot: Node = null
        var nearest_distance := INF
        var reachable_bot: Node = null
        var reachable_distance := INF
        for bot in bots:
            if not is_instance_valid(bot) or bot.dead:
                continue
            var distance := bot.global_position.distance_to(site_position)
            if distance < nearest_distance:
                nearest_distance = distance
                nearest_bot = bot
            if _bot_has_navigation_path(bot, site_position) and distance < reachable_distance:
                reachable_distance = distance
                reachable_bot = bot

        var selected_defuser := reachable_bot if reachable_bot != null else nearest_bot
        if selected_defuser != null:
            active_defuser = selected_defuser
            bot_defuse_time_left = DEFUSE_TIME
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
            # Bot eliminations are scored by the bot's `eliminated` signal.
            # Keep this path limited to applying damage to avoid double rewards.
            hit.collider.take_damage(int(weapon["damage"]))

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
    combat_slot_update_timer = 0.0
    combat_assignment_update_timer = 0.0
    combat_engagement_revision += 1
    combat_role_revision += 1
    combat_assignment_contact_revision = -1
    combat_assignment_objective_state = ""
    combat_assignment_objective_site = ""
    combat_assignment_dropped_position = Vector3.ZERO
    dropped_bomb_position = Vector3.ZERO
    tactical_memory_position = Vector3.ZERO
    tactical_memory_timer = 0.0
    tactical_memory_revision += 1
    squad_contact_position = Vector3.ZERO
    squad_contact_timer = 0.0
    squad_contact_revision += 1
    squad_contact_source = null
    squad_contact_update_timer = 0.0
    last_known_player_position = Vector3.ZERO
    last_known_player_timer = 0.0
    squad_search_active = false
    squad_search_timer = 0.0
    squad_search_update_timer = 0.0
    squad_search_revision += 1
    squad_search_cycle = 0
    squad_threat_state = "LOST"
    squad_threat_position = Vector3.ZERO
    squad_threat_timer = 0.0
    squad_threat_revision += 1
    combat_assignment_threat_revision = -1
    combat_director_phase = "IDLE"
    combat_director_timer = 0.0
    combat_director_revision += 1
    combat_director_contact_revision = -1
    combat_director_threat_revision = -1
    combat_contact_started_at = Time.get_ticks_msec()

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
    var spawn_index := 0
    for bot in bots:
        if is_instance_valid(bot):
            bot.reset_target()
            if not red_spawn_points.is_empty():
                bot.global_position = red_spawn_points[spawn_index % red_spawn_points.size()]
            bot.velocity = Vector3.ZERO
            bot.rotation = Vector3.ZERO
            spawn_index += 1
            count += 1
    enemies_alive = count

func _update_bots(delta: float) -> void:
    if round_state != "LIVE":
        return

    combat_slot_update_timer = maxf(0.0, combat_slot_update_timer - delta)
    if combat_slot_update_timer <= 0.0:
        _update_combat_slots()
        combat_slot_update_timer = COMBAT_SLOT_UPDATE_INTERVAL

    combat_assignment_update_timer = maxf(0.0, combat_assignment_update_timer - delta)
    var contact_revision_changed := squad_contact_revision != combat_assignment_contact_revision
    var threat_revision_changed := squad_threat_revision != combat_assignment_threat_revision
    var objective_state_changed := str(objective_state) != combat_assignment_objective_state
    var objective_site_changed := str(planted_site) != combat_assignment_objective_site
    var dropped_position_changed := objective_state == "DROPPED" and dropped_bomb_position.distance_to(combat_assignment_dropped_position) >= 0.5
    if combat_assignment_update_timer <= 0.0 or contact_revision_changed or threat_revision_changed or objective_state_changed or objective_site_changed or dropped_position_changed:
        _update_combat_assignments()
        combat_assignment_update_timer = COMBAT_ASSIGNMENT_UPDATE_INTERVAL
        combat_assignment_contact_revision = squad_contact_revision
        combat_assignment_threat_revision = squad_threat_revision
        combat_assignment_objective_state = str(objective_state)
        combat_assignment_objective_site = str(planted_site)
        combat_assignment_dropped_position = dropped_bomb_position

    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            bot.process_mode = Node.PROCESS_MODE_INHERIT

func _update_tactical_memory(delta: float) -> void:
    tactical_memory_timer = maxf(0.0, tactical_memory_timer - delta)
    squad_contact_timer = maxf(0.0, squad_contact_timer - delta)
    squad_contact_update_timer = maxf(0.0, squad_contact_update_timer - delta)
    last_known_player_timer = maxf(0.0, last_known_player_timer - delta)
    squad_search_update_timer = maxf(0.0, squad_search_update_timer - delta)

    if not is_instance_valid(player) or dead:
        squad_contact_source = null
        return

    var contact_source: Node = _select_contact_source()
    var contact_position := player.global_position if contact_source != null else Vector3.ZERO

    if contact_source != null and squad_contact_update_timer <= 0.0:
        var source_changed := squad_contact_source != contact_source
        var position_changed := squad_contact_position.distance_to(contact_position) >= 1.0
        squad_contact_source = contact_source
        squad_contact_position = contact_position
        squad_contact_timer = CONTACT_MEMORY_TIMEOUT
        squad_contact_update_timer = CONTACT_UPDATE_INTERVAL
        if source_changed or position_changed:
            squad_contact_revision += 1
            combat_engagement_revision += 1
            combat_contact_started_at = Time.get_ticks_msec()
        last_known_player_position = contact_position
        last_known_player_timer = TACTICAL_MEMORY_TIMEOUT
        tactical_memory_position = contact_position
        tactical_memory_timer = TACTICAL_MEMORY_TIMEOUT
        tactical_memory_revision += 1
        squad_search_active = false
        squad_search_timer = 0.0
        squad_search_update_timer = 0.0
    elif squad_contact_timer <= 0.0:
        if squad_contact_source != null:
            squad_contact_revision += 1
            combat_engagement_revision += 1
        squad_contact_source = null
        squad_contact_position = Vector3.ZERO

    if squad_search_active:
        squad_search_timer = maxf(0.0, squad_search_timer - delta)
        if contact_source != null:
            squad_search_active = false
            squad_search_timer = 0.0
            squad_search_update_timer = 0.0
        elif squad_search_timer <= 0.0:
            squad_search_active = false
            squad_search_timer = 0.0
            squad_search_update_timer = 0.0
            last_known_player_timer = 0.0
        elif squad_search_update_timer <= 0.0:
            squad_search_cycle += 1
            squad_search_revision += 1
            squad_search_update_timer = SQUAD_SEARCH_UPDATE_INTERVAL

    if contact_source != null:
        return

    if not _player_has_bot_los():
        if not squad_search_active and not _is_squad_contact_active() and last_known_player_position != Vector3.ZERO and last_known_player_timer > 0.0 and tactical_memory_timer <= 0.0:
            squad_search_active = true
            squad_search_timer = SQUAD_SEARCH_DURATION
            squad_search_update_timer = 0.0
            squad_search_revision += 1
        return

    var memory_position := player.global_position
    var valid_position := true
    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            if bot.global_position.distance_to(memory_position) > TACTICAL_MEMORY_MAX_DISTANCE:
                valid_position = false
                break
    if not valid_position:
        return

    last_known_player_position = memory_position
    last_known_player_timer = TACTICAL_MEMORY_TIMEOUT
    if tactical_memory_timer > 0.0 and tactical_memory_position != Vector3.ZERO:
        return

    tactical_memory_position = memory_position
    tactical_memory_timer = TACTICAL_MEMORY_TIMEOUT
    tactical_memory_revision += 1
    squad_search_active = false
    squad_search_timer = 0.0
    squad_search_update_timer = 0.0

func _select_contact_source() -> Node:
    if is_instance_valid(squad_contact_source) and not squad_contact_source.dead and bool(squad_contact_source.call("_has_line_of_sight")):
        return squad_contact_source

    var best_bot: Node = null
    var best_score := INF
    for bot in bots:
        if not is_instance_valid(bot) or bot.dead:
            continue
        if not bool(bot.call("_has_line_of_sight")):
            continue

        var distance := bot.global_position.distance_to(player.global_position)
        var assignment := str(bot.get("combat_assignment"))
        var role_bonus := 0.0
        if assignment == "PRESSURE":
            role_bonus = -3.0
        elif assignment == "SUPPORT":
            role_bonus = -1.0
        elif assignment == "FLANK":
            role_bonus = 0.5

        var score := distance + role_bonus
        if score < best_score:
            best_score = score
            best_bot = bot

    return best_bot

func _is_squad_contact_active() -> bool:
    return squad_contact_position != Vector3.ZERO and squad_contact_timer > 0.0

func _get_bot_squad_contact(bot: Node) -> Dictionary:
    if not _is_squad_contact_active():
        return {"position": Vector3.ZERO, "time_left": 0.0, "revision": squad_contact_revision, "source": null}
    return {"position": squad_contact_position, "time_left": squad_contact_timer, "revision": squad_contact_revision, "source": squad_contact_source}

func _update_squad_threat(delta: float) -> void:
    var next_state := "LOST"
    var next_position := Vector3.ZERO
    var next_timer := 0.0

    if _is_squad_contact_active():
        next_state = "CONTACT"
        next_position = squad_contact_position
        next_timer = squad_contact_timer
    elif tactical_memory_position != Vector3.ZERO and tactical_memory_timer > 0.0:
        next_state = "TRACKED"
        next_position = tactical_memory_position
        next_timer = tactical_memory_timer
    elif squad_search_active and squad_search_timer > 0.0:
        next_state = "SEARCHING"
        next_position = last_known_player_position
        next_timer = squad_search_timer

    var state_changed := next_state != squad_threat_state
    var position_changed := squad_threat_position.distance_to(next_position) >= 1.5
    if state_changed or position_changed:
        squad_threat_state = next_state
        squad_threat_position = next_position
        squad_threat_timer = next_timer
        squad_threat_revision += 1
    else:
        squad_threat_timer = next_timer

func _get_squad_threat() -> Dictionary:
    return {
        "state": squad_threat_state,
        "position": squad_threat_position,
        "time_left": squad_threat_timer,
        "revision": squad_threat_revision
    }

func _update_combat_director(delta: float) -> void:
    combat_director_timer = maxf(0.0, combat_director_timer - delta)
    if combat_director_timer > 0.0 and combat_director_contact_revision == squad_contact_revision and combat_director_threat_revision == squad_threat_revision:
        return

    combat_director_timer = COMBAT_DIRECTOR_UPDATE_INTERVAL
    var next_phase := "IDLE"
    if _is_squad_contact_active():
        var contact_age := maxf(0.0, (Time.get_ticks_msec() - combat_contact_started_at) / 1000.0)
        if contact_age >= COMBAT_FLANK_DELAY:
            next_phase = "FLANK"
        elif contact_age >= COMBAT_SUPPORT_DELAY:
            next_phase = "SUPPRESS"
        else:
            next_phase = "CONTACT"
    elif squad_threat_state == "SEARCHING":
        next_phase = "SEARCH"
    elif squad_threat_state == "TRACKED":
        next_phase = "TRACKED"
    elif squad_threat_state == "LOST":
        next_phase = "LOST"

    if next_phase != combat_director_phase or combat_director_contact_revision != squad_contact_revision or combat_director_threat_revision != squad_threat_revision:
        combat_director_phase = next_phase
        combat_director_revision += 1
    combat_director_contact_revision = squad_contact_revision
    combat_director_threat_revision = squad_threat_revision

func _get_bot_combat_director(bot: Node) -> Dictionary:
    var assignment := str(bot.get("combat_assignment"))
    var threat := squad_threat_state
    var phase := combat_director_phase
    var command := "HOLD"
    var fire_ready := false

    if _is_squad_contact_active():
        var contact_age := maxf(0.0, (Time.get_ticks_msec() - combat_contact_started_at) / 1000.0)
        if assignment == "PRESSURE":
            phase = "CONTACT"
            command = "PUSH"
            fire_ready = true
        elif assignment == "SUPPORT":
            phase = "SUPPRESS"
            command = "SUPPRESS"
            fire_ready = contact_age >= COMBAT_SUPPORT_DELAY
        elif assignment == "FLANK":
            phase = "FLANK"
            command = "FLANK"
            fire_ready = contact_age >= COMBAT_FLANK_DELAY
    elif _is_squad_search_active():
        phase = "SEARCH"
    elif squad_search_active:
        phase = "SEARCH"
        command = "HOLD"
    elif threat == "SEARCHING":
        phase = "SEARCH"
        command = "HOLD"
    elif threat == "TRACKED":
        phase = "TRACKED"
        command = "HOLD"
    else:
        phase = "LOST"
        command = "HOLD"

    return {
        "phase": phase,
        "command": command,
        "fire_ready": fire_ready,
        "revision": combat_director_revision,
        "contact_revision": squad_contact_revision,
        "role_revision": combat_role_revision,
        "contact_source": squad_contact_source,
        "threat": threat,
        "threat_position": squad_threat_position,
        "threat_revision": squad_threat_revision
    }

func _player_has_bot_los() -> bool:
    if not is_instance_valid(player):
        return false
    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            var origin := bot.global_position + Vector3(0, 1.0, 0)
            var target_position := player.global_position + Vector3(0, 0.5, 0)
            var query := PhysicsRayQueryParameters3D.create(origin, target_position)
            query.exclude = [bot]
            var hit := get_world_3d().direct_space_state.intersect_ray(query)
            if hit.is_empty() or hit.collider == player:
                return true
    return false

func _get_bot_tactical_memory(bot: Node) -> Dictionary:
    if tactical_memory_position == Vector3.ZERO or tactical_memory_timer <= 0.0:
        return {"position": Vector3.ZERO, "time_left": 0.0, "revision": tactical_memory_revision}

    return {
        "position": tactical_memory_position,
        "time_left": tactical_memory_timer,
        "revision": tactical_memory_revision
    }

func _get_bot_squad_engagement_target(bot: Node) -> Vector3:
    if not is_instance_valid(player):
        return Vector3.ZERO

    var target_position := player.global_position
    var bot_assignment := str(bot.get("combat_assignment"))
    var has_los := bool(bot.call("_has_line_of_sight"))
    var contact_active := _is_squad_contact_active()
    var memory_position := tactical_memory_position
    var memory_active := memory_position != Vector3.ZERO and tactical_memory_timer > 0.0

    if not has_los and contact_active:
        target_position = squad_contact_position
    elif not has_los and memory_active:
        target_position = memory_position

    if has_los:
        return target_position
    if not contact_active and not memory_active:
        return target_position

    if contact_active:
        memory_position = squad_contact_position

    var from_memory := bot.global_position - memory_position
    from_memory.y = 0.0
    if from_memory.length() < 0.1:
        from_memory = Vector3(0, 0, 1)
    var forward := from_memory.normalized()
    var side := Vector3(-forward.z, 0.0, forward.x)

    if bot_assignment == "FLANK":
        var flank_side := -1.0 if int(bot.get("combat_slot")) == 0 else 1.0
        target_position += side * flank_side * 4.0
    elif bot_assignment == "SUPPORT":
        target_position -= side * 2.5

    return target_position

func _is_squad_search_active() -> bool:
    return squad_search_active and last_known_player_position != Vector3.ZERO and squad_search_timer > 0.0

func _get_bot_squad_search_goal(bot: Node) -> Vector3:
    if not _is_squad_search_active():
        return Vector3.ZERO

    var center := last_known_player_position
    var assignment := str(bot.get("combat_assignment"))
    var slot := int(bot.get("combat_slot"))

    var forward := Vector3(0, 0, 1)
    var from_center := bot.global_position - center
    from_center.y = 0.0
    if from_center.length() >= 0.1:
        forward = from_center.normalized()
    var side := Vector3(-forward.z, 0.0, forward.x)

    var cycle_offset := float(squad_search_cycle % 3) * SQUAD_SEARCH_FORWARD_STEP
    var sector := Vector3.ZERO
    if assignment == "PRESSURE":
        sector = forward * cycle_offset
    elif assignment == "SUPPORT":
        sector = side * SQUAD_SEARCH_SECTOR_RADIUS + forward * cycle_offset
    elif assignment == "FLANK":
        sector = -side * SQUAD_SEARCH_SECTOR_RADIUS + forward * cycle_offset
    else:
        sector = side * (float(slot) - 1.0) * SQUAD_SEARCH_SECTOR_RADIUS

    var goal := center + sector
    goal.y = center.y
    return goal

func _get_threat_role_score(bot: Node, role: String) -> float:
    var threat_position := squad_threat_position
    if threat_position == Vector3.ZERO:
        threat_position = player.global_position

    var distance := bot.global_position.distance_to(threat_position)
    var slot := int(bot.get("combat_slot"))
    var score := distance

    if squad_threat_state == "CONTACT":
        if role == "PRESSURE":
            score += float(maxi(0, 2 - slot)) * 1.5
            score -= float(bot.get("health")) * 0.025
        elif role == "SUPPORT":
            score += absf(float(slot) - 1.0) * 1.0
            score += float(maxi(0, 55 - int(bot.get("health")))) * 0.02
        elif role == "FLANK":
            score += absf(float(slot) - 1.0) * 0.4
            score -= absf(float(slot) - 1.0) * 0.8
    elif squad_threat_state == "TRACKED":
        if role == "PRESSURE":
            score -= 2.5
            score -= float(bot.get("health")) * 0.015
        elif role == "SUPPORT":
            score += 1.0
            score += absf(float(slot) - 1.0) * 0.35
        elif role == "FLANK":
            score -= absf(float(slot) - 1.0) * 1.5
            score += 0.5
    elif squad_threat_state == "SEARCHING":
        var center_bias := absf(float(slot) - 2.0)
        if role == "PRESSURE":
            score += center_bias * 2.0
            score -= 2.0
        elif role == "SUPPORT":
            score += absf(float(slot) - 0.0) * 0.8
        elif role == "FLANK":
            score += absf(float(slot) - 1.0) * 0.4
            score -= 0.8
    else:
        if role == "PRESSURE":
            score += 4.0
        elif role == "SUPPORT":
            score += 1.0
        elif role == "FLANK":
            score += 1.5

    return score

func _select_threat_role_bot(candidates: Array[Node], role: String, previous_roles: Dictionary) -> Node:
    var selected: Node = null
    var best_score := INF
    for bot in candidates:
        if not is_instance_valid(bot) or bot.dead:
            continue
        var score := _get_threat_role_score(bot, role)

        var previous_role := str(previous_roles.get(bot, ""))
        if previous_role == role:
            score -= 1.25

        if squad_threat_state == "LOST":
            if role == "PRESSURE" and previous_role == "PRESSURE":
                score -= 0.5
            elif role == "FLANK" and previous_role == "FLANK":
                score -= 0.25

        if score < best_score:
            best_score = score
            selected = bot
    return selected

func _threat_role_aggression(bot: Node) -> float:
    var assignment := str(bot.get("combat_assignment"))
    if squad_threat_state == "CONTACT":
        if assignment == "PRESSURE":
            return 1.0
        if assignment == "SUPPORT":
            return 0.72
        return 0.62
    if squad_threat_state == "TRACKED":
        if assignment == "PRESSURE":
            return 0.68
        if assignment == "SUPPORT":
            return 0.42
        return 0.50
    if squad_threat_state == "SEARCHING":
        return 0.18
    return 0.05

func _update_combat_assignments() -> void:
    var active_bots: Array[Node] = []
    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            active_bots.append(bot)

    if active_bots.is_empty():
        return

    var previous_roles: Dictionary = {}
    for bot in active_bots:
        previous_roles[bot] = str(bot.get("combat_assignment"))

    var objective_state_now := str(objective_state)
    var objective_active := objective_state_now == "DROPPED" or objective_state_now == "PLANTED"
    var planted_objective := objective_state_now == "PLANTED"
    var objective_position := dropped_bomb_position
    if planted_objective:
        objective_position = bomb_site_a if planted_site == "A" else bomb_site_b
    elif objective_state_now == "DROPPED" and objective_position == Vector3.ZERO:
        objective_active = false

    var remaining := active_bots.duplicate()
    var pressure_bot: Node = null
    var support_bot: Node = null
    var flank_bot: Node = null

    if objective_active:
        var objective_guard: Node = _select_objective_guard_bot(remaining, objective_position, previous_roles)
        if objective_guard != null:
            support_bot = objective_guard
            remaining.erase(objective_guard)

        if planted_objective:
            var objective_cover: Node = _select_objective_guard_bot(remaining, objective_position, previous_roles)
            if objective_cover != null:
                flank_bot = objective_cover
                remaining.erase(objective_cover)

    if not remaining.is_empty():
        pressure_bot = _select_threat_role_bot(remaining, "PRESSURE", previous_roles)
        if pressure_bot != null:
            remaining.erase(pressure_bot)

    if not remaining.is_empty() and support_bot == null:
        support_bot = _select_threat_role_bot(remaining, "SUPPORT", previous_roles)
        if support_bot != null:
            remaining.erase(support_bot)

    if not remaining.is_empty() and flank_bot == null:
        flank_bot = _select_threat_role_bot(remaining, "FLANK", previous_roles)

    for bot in active_bots:
        var assignment := "SUPPORT"
        if bot == pressure_bot:
            assignment = "PRESSURE"
        elif bot == support_bot:
            assignment = "SUPPORT"
        elif bot == flank_bot:
            assignment = "FLANK"

        var previous_assignment := str(bot.get("combat_assignment"))
        if previous_assignment != assignment:
            bot.set("combat_assignment", assignment)
            bot.set("combat_engagement", "HANDOFF")
            combat_role_revision += 1
            combat_engagement_revision += 1

    combat_assignment_contact_revision = squad_contact_revision
    combat_assignment_threat_revision = squad_threat_revision

func _select_objective_guard_bot(candidates: Array[Node], objective_position: Vector3, previous_roles: Dictionary) -> Node:
    var selected: Node = null
    var best_score := INF
    for bot in candidates:
        if not is_instance_valid(bot) or bot.dead:
            continue

        var distance := bot.global_position.distance_to(objective_position)
        var previous_role := str(previous_roles.get(bot, ""))
        var score := distance

        if previous_role == "SUPPORT":
            score -= 1.5
        elif previous_role == "FLANK":
            score -= 0.5

        if squad_threat_state == "CONTACT":
            var threat_distance := bot.global_position.distance_to(squad_threat_position)
            score += minf(threat_distance * 0.15, 3.0)
        elif squad_threat_state == "TRACKED":
            score += minf(bot.global_position.distance_to(squad_threat_position) * 0.08, 2.0)

        if score < best_score:
            best_score = score
            selected = bot

    return selected

func _update_combat_slots() -> void:
    if not is_instance_valid(player):
        return

    var active_bots: Array[CharacterBody3D] = []
    for bot in bots:
        if is_instance_valid(bot) and not bot.dead:
            active_bots.append(bot)

    if active_bots.is_empty():
        return

    var player_right := player.global_transform.basis.x
    player_right.y = 0.0
    if player_right.length() < 0.1:
        player_right = Vector3.RIGHT
    player_right = player_right.normalized()

    var left_bot: CharacterBody3D = null
    var right_bot: CharacterBody3D = null
    var center_bot: CharacterBody3D = null
    var left_value := INF
    var right_value := -INF
    var center_value := INF

    for bot in active_bots:
        var offset := bot.global_position - player.global_position
        offset.y = 0.0
        var lateral := offset.dot(player_right)

        if lateral < left_value:
            left_value = lateral
            left_bot = bot
        if lateral > right_value:
            right_value = lateral
            right_bot = bot

    if active_bots.size() == 1:
        active_bots[0].set("combat_slot", 2)
        return

    if left_bot == right_bot:
        active_bots[0].set("combat_slot", 0)
        if active_bots.size() > 1:
            active_bots[1].set("combat_slot", 1)
        for index in range(2, active_bots.size()):
            active_bots[index].set("combat_slot", 2)
        return

    left_bot.set("combat_slot", 0)
    right_bot.set("combat_slot", 1)

    if active_bots.size() >= 3:
        for bot in active_bots:
            if bot == left_bot or bot == right_bot:
                continue
            var offset := bot.global_position - player.global_position
            offset.y = 0.0
            var lateral := offset.dot(player_right)
            var center_distance := absf(lateral)
            if center_distance < center_value:
                center_value = center_distance
                center_bot = bot

        if center_bot != null:
            center_bot.set("combat_slot", 2)

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
    _build_navigation_graph()

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

func _build_navigation_graph() -> void:
    navigation_graph.clear()
    for i in navigation_points.size():
        var neighbors: Array[int] = []
        for j in navigation_points.size():
            if i == j:
                continue
            if _navigation_visible(navigation_points[i], navigation_points[j]):
                neighbors.append(j)
        navigation_graph.append(neighbors)


func _find_nearest_navigation_point(position: Vector3) -> int:
    var best_index := -1
    var best_distance := INF
    for i in navigation_points.size():
        var distance := navigation_points[i].distance_to(position)
        if distance < best_distance and _navigation_visible(position, navigation_points[i]):
            best_distance = distance
            best_index = i
    return best_index


func _simplify_navigation_route(route: Array) -> Array:
    if route.size() <= 2:
        return route

    var simplified: Array = [route[0]]
    var anchor := 0
    while anchor < route.size() - 1:
        var farthest := anchor + 1
        for candidate in range(anchor + 1, route.size()):
            if _navigation_visible(route[anchor], route[candidate]):
                farthest = candidate
        simplified.append(route[farthest])
        anchor = farthest
    return simplified


func _find_navigation_route(start: Vector3, goal: Vector3) -> Array:
    var points: Array = navigation_points
    if points.is_empty():
        return [goal]

    if navigation_graph.size() != points.size():
        _build_navigation_graph()

    var start_index := _find_nearest_navigation_point(start)
    var goal_index := _find_nearest_navigation_point(goal)

    if start_index < 0 or goal_index < 0:
        return []

    if start_index == goal_index:
        return [goal]

    var open_set: Array[int] = [start_index]
    var closed_set := {}
    var came_from := {}
    var g_score := {}
    var f_score := {}

    for i in points.size():
        g_score[i] = INF
        f_score[i] = INF
    g_score[start_index] = 0.0
    f_score[start_index] = points[start_index].distance_to(points[goal_index])

    while not open_set.is_empty():
        var best_open_index := 0
        var current: int = open_set[0]
        for i in open_set.size():
            var candidate: int = open_set[i]
            if float(f_score.get(candidate, INF)) < float(f_score.get(current, INF)):
                best_open_index = i
                current = candidate
        open_set.remove_at(best_open_index)

        if current == goal_index:
            var indices: Array[int] = []
            var cursor := goal_index
            while true:
                indices.push_front(cursor)
                if cursor == start_index:
                    break
                if not came_from.has(cursor):
                    return []
                cursor = int(came_from[cursor])

            var route: Array = []
            for index in indices:
                route.append(points[index])
            if route.is_empty() or route[route.size() - 1].distance_to(goal) > WAYPOINT_REACHED:
                route.append(goal)
            return _simplify_navigation_route(route)

        closed_set[current] = true
        var neighbors: Array = navigation_graph[current]
        for neighbor_value in neighbors:
            var neighbor: int = int(neighbor_value)
            if closed_set.has(neighbor):
                continue

            var tentative_g := float(g_score[current]) + points[current].distance_to(points[neighbor])
            if tentative_g >= float(g_score.get(neighbor, INF)):
                continue

            came_from[neighbor] = current
            g_score[neighbor] = tentative_g
            f_score[neighbor] = tentative_g + points[neighbor].distance_to(points[goal_index])
            if not open_set.has(neighbor):
                open_set.append(neighbor)

    return []

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
        if not _bot_has_navigation_path(bot, cover_position):
            continue
        if not _has_obstacle_between(player_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if _has_obstacle_between(peek_position, player_position + Vector3(0, 1.0, 0)):
            continue

        var occupied := false
        var spacing_penalty := 0.0
        for other in bots:
            if other == bot or not is_instance_valid(other) or other.dead:
                continue

            var other_cover: Vector3 = other.get("bomb_cover_goal")
            var other_peek: Vector3 = other.get("current_goal")
            if str(other.state) == "BOMB_COVER":
                if other_cover != Vector3.ZERO and other_cover.distance_to(cover_position) < 2.5:
                    occupied = true
                    break
                if other_peek != Vector3.ZERO and other_peek.distance_to(peek_position) < 4.0:
                    occupied = true
                    break

            if other.global_position.distance_to(cover_position) < 2.5:
                occupied = true
                break
            if str(other.state) == "BOMB_COVER" and other.current_goal.distance_to(cover_position) < 2.5:
                occupied = true
                break

            var separation := other.global_position.distance_to(peek_position)
            if str(other.state) == "BOMB_COVER":
                if other_cover != Vector3.ZERO:
                    separation = minf(separation, other_cover.distance_to(peek_position))
                if other_peek != Vector3.ZERO:
                    separation = minf(separation, other_peek.distance_to(peek_position))
            if separation < 4.5:
                spacing_penalty += (4.5 - separation) * 1.8

        if occupied:
            continue

        var bot_distance := bot.global_position.distance_to(cover_position)
        var anchor_bonus := -1.0 if str(data["site"]) == str(planted_site) else 0.0
        var player_to_site := site_position - player_position
        player_to_site.y = 0.0
        var site_to_peek := peek_position - site_position
        site_to_peek.y = 0.0
        var angle_penalty := 0.0
        if player_to_site.length() > 0.1 and site_to_peek.length() > 0.1:
            var approach_side := player_to_site.normalized().dot(site_to_peek.normalized())
            var preferred_side := -1.0 if int(bot.get("combat_slot")) == 0 else (1.0 if int(bot.get("combat_slot")) == 1 else 0.0)
            angle_penalty = absf(approach_side - preferred_side * 0.65) * 1.2

        var score := site_distance * 1.15 + absf(player_distance - 14.0) * 0.22 + bot_distance * 0.18 + anchor_bonus + spacing_penalty + angle_penalty
        if score < best_score:
            best_score = score
            best = cover_position

    return best

func _combat_position_conflict(bot: Node, position: Vector3) -> bool:
    for other in bots:
        if other == bot or not is_instance_valid(other) or other.dead:
            continue
        if other.global_position.distance_to(position) < 2.8:
            return true
        if str(other.state) == "REPOSITION" and other.combat_reposition_goal != Vector3.ZERO:
            if other.combat_reposition_goal.distance_to(position) < 2.8:
                return true
        if str(other.state) == "ATTACK" or str(other.state) == "PEEK":
            if other.current_goal.distance_to(position) < 2.8:
                return true
    return false

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

        if not _bot_has_navigation_path(bot, peek_position):
            continue

        var from_player := peek_position - player_position
        from_player.y = 0.0
        if from_player.length() < 0.1:
            continue
        var direction_from_player := from_player.normalized()
        var lateral := absf(direction_from_player.dot(side))
        var forward_alignment := direction_from_player.dot(forward)
        var slot_target := 0.85 if target_side != 0.0 else 0.35
        var slot_score := absf(lateral - slot_target)
        if target_side != 0.0:
            slot_score += maxf(0.0, -forward_alignment) * 0.25
        else:
            slot_score += absf(forward_alignment) * 0.12

        var conflict_penalty := 0.0
        for other in bots:
            if other == bot or not is_instance_valid(other) or other.dead:
                continue
            var other_position := other.global_position
            var separation := other_position.distance_to(peek_position)
            if str(other.state) == "REPOSITION" and other.combat_reposition_goal != Vector3.ZERO:
                separation = minf(separation, other.combat_reposition_goal.distance_to(peek_position))
            elif str(other.state) == "ATTACK" or str(other.state) == "PEEK":
                separation = minf(separation, other.current_goal.distance_to(peek_position))
            if separation < 2.8:
                conflict_penalty += 12.0
            elif separation < 5.0:
                conflict_penalty += 3.0
        var slot_separation_bonus := 0.0
        if target_side != 0.0:
            slot_separation_bonus = -lateral * 1.5

        var score := bot_distance * 0.25 + absf(player_distance - 14.0) * 0.45 + slot_score * 4.0 + conflict_penalty + slot_separation_bonus
        if _combat_position_conflict(bot, peek_position):
            score += 8.0
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

        if not _bot_has_navigation_path(bot, cover_position):
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
