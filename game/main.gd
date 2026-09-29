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
const MAX_BOT_COUNT := 15
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

const WEAPON_ASSETS := [
    preload("res://data/ar_17.tres"),
    preload("res://data/px_9.tres")
]

var weapons: Array[Dictionary] = []

var combat_events: OpenStrikeCombatEvents
var combat_authority: OpenStrikeCombatAuthority
var player_snapshots := OpenStrikeSnapshotHistory.new()
var input_sequence := 0
var last_processed_input_sequence := 0
var prediction := OpenStrikePredictionController.new()
var network_diagnostics := OpenStrikeNetworkDiagnostics.new()
var network_session: OpenStrikeNetworkSession
var pending_look_delta := Vector2.ZERO
var pending_buy_weapon_id := ""
var pending_switch_weapon := false
var pending_reload := false
var pending_objective := false
var pending_prediction_replay := false
var prediction_replay_position := Vector3.ZERO
var prediction_replay_velocity := Vector3.ZERO
var prediction_replay_yaw := 0.0
var prediction_replay_pitch := 0.0
var prediction_replay_tick := 0
var prediction_replay_commands: Array[OpenStrikeInputCommand] = []
var deferred_prediction_snapshot: OpenStrikeSnapshot = null

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
var hud_layer: CanvasLayer
var elimination_feedback_label: Label
var elimination_feedback_timer := 0.0
var crosshair_root: Control
var crosshair_segments: Array[ColorRect] = []
var network_debug_hud: Label
var network_debug_visible := false
var view_weapon_root: Node3D
var view_weapon_base_position := Vector3(0.28, -0.24, -0.56)
var view_weapon_bob_time := 0.0
var camera_bob_time := 0.0
var camera_bob_offset := Vector2.ZERO
var view_weapon_recoil := 0.0
var view_weapon_reload_timer := 0.0
var view_weapon_inspect_timer := 0.0
const VIEW_WEAPON_RELOAD_DURATION := 0.62
const VIEW_WEAPON_INSPECT_DURATION := 1.10
var muzzle_flash: MeshInstance3D
var muzzle_flash_timer := 0.0
var shell_casing_material: StandardMaterial3D
var hit_marker: Label
var damage_flash: ColorRect
var low_health_vignette: ColorRect
var low_health_pulse_time := 0.0
var objective_progress_bar: ProgressBar
var objective_progress_label: Label
var hit_feedback_timer := 0.0
var damage_feedback_timer := 0.0

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
var round_outcome_resolved := false
var round_outcome_reason := ""
var credits := STARTING_CREDITS
var primary_owned := false

var objective_state := "CARRIED"
var bomb_carrier_peer_id := 0
var objective_site := ""
var planted_site := ""
var dropped_bomb_position := Vector3.ZERO
var bomb_visual: MeshInstance3D
var bomb_light: OmniLight3D
var bomb_status_material: StandardMaterial3D
var bomb_time_left := 0.0
var objective_action := ""
var objective_action_time_left := 0.0
var bot_defuse_time_left := 0.0
var active_defuser: Node = null
var network_objective_peer_id := -1
var network_objective_latched_peer_id := -1
var bomb_defense_revision := 0
var bot_count := BOT_COUNT
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
var processed_elimination_ids := {}

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
    _configure_bot_count_from_command_line()
    _load_weapon_catalog()
    combat_events = OpenStrikeCombatEvents.new()
    add_child(combat_events)
    combat_authority = OpenStrikeCombatAuthority.new()
    add_child(combat_authority)
    combat_authority.setup(combat_events)
    combat_events.combat_event.connect(_on_combat_event)
    network_session = OpenStrikeNetworkSession.new()
    add_child(network_session)
    network_session.snapshot_received.connect(_on_authoritative_snapshot)
    network_session.input_rejected.connect(_on_network_input_rejected)
    network_session.input_rejected_reason.connect(_on_network_input_rejected_reason)
    bomb_site_a = BOMB_SITE_A
    bomb_site_b = BOMB_SITE_B
    _player()
    _world()
    _hud()
    _create_crosshair()
    _create_elimination_feedback()
    _create_network_debug_hud()
    _start_round()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead:
        player.rotate_y(-event.relative.x * SENS)
        pitch = clamp(pitch - event.relative.y * SENS, -1.45, 1.45)
        pending_look_delta += event.relative
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_F3:
            network_debug_visible = not network_debug_visible
            if network_debug_hud != null:
                network_debug_hud.visible = network_debug_visible
        elif event.keycode == KEY_1 and not dead:
            if network_session != null and network_session.is_online and not network_session.is_server:
                pending_buy_weapon_id = str(weapons[0]["id"])
            else:
                _buy_weapon(0)
        elif event.keycode == KEY_2 and not dead:
            if network_session != null and network_session.is_online and not network_session.is_server:
                pending_buy_weapon_id = str(weapons[1]["id"])
            else:
                _buy_weapon(1)
        elif event.keycode == KEY_E and not dead:
            if network_session != null and network_session.is_online and not network_session.is_server:
                pending_switch_weapon = true
            else:
                _switch_weapon()
        elif event.keycode == KEY_T and not dead:
            if view_weapon_inspect_timer <= 0.0 and view_weapon_reload_timer <= 0.0:
                view_weapon_inspect_timer = VIEW_WEAPON_INSPECT_DURATION
        elif event.keycode == KEY_R and not dead:
            if network_session != null and network_session.is_online and not network_session.is_server:
                pending_reload = true
            else:
                _reload()
        elif event.keycode == KEY_F and not dead:
            var network_client := network_session != null and network_session.is_online and not network_session.is_server
            if network_client:
                pending_objective = true
            else:
                _begin_objective_action()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dead:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    _update_view_weapon_motion(delta)
    _update_crosshair()
    _update_elimination_feedback(delta)

func _update_view_weapon_motion(delta: float) -> void:
    if not is_instance_valid(view_weapon_root) or not is_instance_valid(player):
        return
    var local_velocity := player.global_transform.basis.inverse() * player.velocity
    local_velocity.y = 0.0
    var speed_ratio := clampf(local_velocity.length() / 5.6, 0.0, 1.0)
    view_weapon_bob_time += delta * (2.0 + speed_ratio * 7.5)
    view_weapon_recoil = move_toward(view_weapon_recoil, 0.0, delta * 0.72)
    view_weapon_reload_timer = maxf(0.0, view_weapon_reload_timer - delta)
    view_weapon_inspect_timer = maxf(0.0, view_weapon_inspect_timer - delta)
    var reload_phase := 1.0 - view_weapon_reload_timer / VIEW_WEAPON_RELOAD_DURATION
    var reload_amount := sin(clampf(reload_phase, 0.0, 1.0) * PI)
    var inspect_phase := 1.0 - view_weapon_inspect_timer / VIEW_WEAPON_INSPECT_DURATION
    var inspect_amount := sin(clampf(inspect_phase, 0.0, 1.0) * PI)
    var bob_amount := speed_ratio * (0.012 if not crouched else 0.006)
    var bob_x := cos(view_weapon_bob_time * 0.5) * bob_amount * 0.65

    # Subtle camera head-bob and lateral sway make movement feel grounded.
    # The offset is cosmetic and remains local to the first-person camera.
    camera_bob_time += delta * (2.0 + speed_ratio * (7.0 if not crouched else 5.0))
    var camera_bob_strength := speed_ratio * (0.024 if not crouched else 0.010)
    var camera_target_offset := Vector2(
        -local_velocity.x * 0.0018 + sin(camera_bob_time * 0.5) * camera_bob_strength * 0.32,
        absf(sin(camera_bob_time)) * camera_bob_strength
    )
    camera_bob_offset = camera_bob_offset.lerp(camera_target_offset, minf(delta * 8.0, 1.0))
    if is_instance_valid(camera):
        camera.position.x = camera_bob_offset.x
        camera.position.y = (CROUCH_CAMERA_Y if crouched else STAND_CAMERA_Y) + camera_bob_offset.y
    var bob_y := absf(sin(view_weapon_bob_time)) * bob_amount
    var sway_x := clampf(-local_velocity.x * 0.006, -0.035, 0.035)
    var target_position := view_weapon_base_position + Vector3(
        sway_x + bob_x + 0.12 * inspect_amount,
        bob_y - 0.20 * reload_amount - 0.10 * inspect_amount,
        view_weapon_recoil + 0.06 * reload_amount + 0.06 * inspect_amount
    )
    var target_rotation := Vector3(
        sin(view_weapon_bob_time) * bob_amount * 0.65 - 0.18 * reload_amount + 0.10 * inspect_amount,
        0.38 * inspect_amount,
        -local_velocity.x * 0.006 + 0.22 * reload_amount - 0.48 * inspect_amount
    )
    view_weapon_root.position = view_weapon_root.position.lerp(target_position, minf(delta * 10.0, 1.0))
    view_weapon_root.rotation = view_weapon_root.rotation.lerp(target_rotation, minf(delta * 9.0, 1.0))

func _physics_process(delta: float) -> void:
    if network_session != null and network_session.is_server:
        network_session.set_server_tick(combat_events.tick)
    _update_bomb_visual()
    player_snapshots.push(combat_events.tick, player.global_position, player.rotation.y, health)
    var network_client := network_session != null and network_session.is_online and not network_session.is_server
    if dead:
        if network_client:
            _update_hud()
            return
        respawn_timer = maxf(0.0, respawn_timer - delta)
        if respawn_timer <= 0.0:
            _respawn_player()
        _update_hud()
        return

    if not network_client:
        _update_round_state(delta)
    if network_client and round_state == "LIVE" and pending_prediction_replay:
        _replay_pending_prediction(delta)
    if round_state != "LIVE":
        if network_client and (pending_buy_weapon_id != "" or pending_switch_weapon or pending_reload):
            var buy_command := prediction.build_command(
                combat_events.tick,
                Vector2.ZERO,
                pending_look_delta,
                false,
                false,
                false,
                false,
                str(_current_weapon()["id"])
            )
            buy_command.buy_weapon_id = pending_buy_weapon_id
            buy_command.switch_weapon = pending_switch_weapon
            if pending_buy_weapon_id != "":
                buy_command.weapon_id = pending_buy_weapon_id
            elif pending_switch_weapon:
                buy_command.weapon_id = ""
            pending_look_delta = Vector2.ZERO
            pending_buy_weapon_id = ""
            pending_switch_weapon = false
            pending_reload = false
            prediction.record_predicted(buy_command, player.global_position, player.velocity, player.rotation.y, pitch)
            input_sequence = buy_command.sequence
            network_diagnostics.record_command()
            network_session.send_input(buy_command)
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
    if network_session == null or not network_session.is_online or network_session.is_server:
        _update_objective(delta)
    cooldown = maxf(0.0, cooldown - delta)
    muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
    if muzzle_flash != null and muzzle_flash_timer <= 0.0:
        muzzle_flash.visible = false
    recoil_kick = move_toward(recoil_kick, 0.0, delta * 0.20)
    hit_feedback_timer = maxf(0.0, hit_feedback_timer - delta)
    damage_feedback_timer = maxf(0.0, damage_feedback_timer - delta)
    _update_combat_feedback()

    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var command := prediction.build_command(
        combat_events.tick,
        input,
        pending_look_delta,
        Input.is_action_pressed("fire"),
        Input.is_action_just_pressed("reload") or pending_reload,
        Input.is_action_pressed("crouch"),
        Input.is_action_just_pressed("jump"),
        str(_current_weapon()["id"]),
        Input.is_key_pressed(KEY_F) or pending_objective
    )
    command.buy_weapon_id = pending_buy_weapon_id
    command.switch_weapon = pending_switch_weapon
    if pending_buy_weapon_id != "":
        command.weapon_id = pending_buy_weapon_id
    elif pending_switch_weapon:
        command.weapon_id = ""
    pending_look_delta = Vector2.ZERO
    pending_buy_weapon_id = ""
    pending_switch_weapon = false
    pending_reload = false
    pending_objective = false
    prediction.record_predicted(command, player.global_position, player.velocity, player.rotation.y, pitch)
    input_sequence = command.sequence
    network_diagnostics.record_command()
    if network_session != null and network_session.is_online and not network_session.is_server:
        network_session.send_input(command)

    var direction := (player.transform.basis * Vector3(command.move.x, 0, command.move.y)).normalized()
    # Match the network server's movement constants while predicting online.
    # Offline movement continues to use each weapon's configured speed.
    var network_client := network_session != null and network_session.is_online and not network_session.is_server
    var move_speed := (3.4 if command.crouch else 5.6) if network_client else _current_speed()
    player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, 25.0 * delta)
    player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, 25.0 * delta)

    if command.jump and player.is_on_floor() and not crouched:
        player.velocity.y = 5.0

    var want_crouch := command.crouch
    if want_crouch != crouched:
        _set_crouch(want_crouch)

    if command.fire and not network_client:
        _fire()
    if command.reload and not network_client:
        _reload()

    player.move_and_slide()
    camera.rotation.x = pitch + recoil_kick
    _update_hud()

func _on_network_input_rejected(_peer_id: int, _command: OpenStrikeInputCommand) -> void:
	network_diagnostics.record_rejected_input()

func _on_network_input_rejected_reason(_peer_id: int, _command: OpenStrikeInputCommand, reason: String) -> void:
	network_diagnostics.record_rejection_reason(reason)


func _on_authoritative_snapshot(snapshot: OpenStrikeSnapshot) -> void:
    if snapshot == null:
        return
    var was_dead := dead
    var previous_round_number := round_number
    network_diagnostics.record_snapshot(snapshot.peer_id, snapshot.tick, snapshot.round_number, snapshot.acknowledged_input_sequence)
    var acknowledged_sequence := mini(snapshot.acknowledged_input_sequence, input_sequence)
    prediction.acknowledge(acknowledged_sequence)
    last_processed_input_sequence = maxi(last_processed_input_sequence, acknowledged_sequence)
    health = snapshot.health
    dead = snapshot.dead
    if dead and not was_dead:
        respawn_timer = RESPAWN_DELAY
    elif not dead:
        respawn_timer = 0.0
    if snapshot.round_state != "":
        round_state = snapshot.round_state
    round_number = snapshot.round_number
    if snapshot.round_number != previous_round_number:
        prediction.clear_pending()
        deferred_prediction_snapshot = null
        pending_buy_weapon_id = ""
        pending_switch_weapon = false
        pending_reload = false
        pending_objective = false
        pending_look_delta = Vector2.ZERO
        cooldown = 0.0
        recoil_kick = 0.0
        _clear_objective_action()
        network_objective_peer_id = -1
        network_objective_latched_peer_id = -1
        objective_site = ""
        bot_defuse_time_left = 0.0
        active_defuser = null
    round_won = snapshot.round_won
    round_outcome_reason = snapshot.round_outcome_reason
    objective_state = snapshot.objective_state
    planted_site = snapshot.planted_site
    bomb_time_left = snapshot.bomb_time_left
    bomb_carrier_peer_id = snapshot.carrier_peer_id
    dropped_bomb_position = snapshot.dropped_bomb_position
    objective_action = snapshot.objective_action
    objective_action_peer_id = snapshot.objective_action_peer_id
    objective_action_time_left = snapshot.objective_action_time_left
    credits = clampi(snapshot.credits, 0, MAX_CREDITS)
    primary_owned = snapshot.owned_weapons.has("ar_17")
    var authoritative_index := -1
    for i in weapons.size():
        if str(weapons[i].get("id", "")) == snapshot.weapon_id:
            authoritative_index = i
            break
    if authoritative_index >= 0:
        weapon_index = authoritative_index
        ammo = snapshot.ammo
        reserve = snapshot.reserve
        _refresh_view_weapon()

    # Keep the newest authoritative transform until the current rollback finishes.
    # ACK state is still processed above, but the transform itself must not be
    # mixed into an in-flight replay timeline.
    if pending_prediction_replay:
        if deferred_prediction_snapshot == null or snapshot.tick > deferred_prediction_snapshot.tick:
            deferred_prediction_snapshot = snapshot
        return

    _start_prediction_replay(snapshot)


func _replay_pending_prediction(delta: float) -> void:
    if player == null or prediction_replay_commands.is_empty():
        pending_prediction_replay = false
        prediction_replay_commands.clear()
        if deferred_prediction_snapshot != null:
            var latest_snapshot := deferred_prediction_snapshot
            deferred_prediction_snapshot = null
            if not dead:
                _start_prediction_replay(latest_snapshot)
        return

    # Roll back to the authoritative state, then replay only movement/look
    # inputs. Fire, reload, buy, weapon-switch and objective side effects are
    # deliberately excluded so reconciliation cannot duplicate gameplay.
    player.global_position = prediction_replay_position
    player.velocity = prediction_replay_velocity
    player.rotation.y = prediction_replay_yaw
    pitch = prediction_replay_pitch

    var physics_step := 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second))
    for command in prediction_replay_commands:
        if command == null:
            continue
        var tick_delta := maxi(1, command.tick - prediction_replay_tick)
        prediction_replay_tick = command.tick
        player.rotate_y(-command.look_delta.x * SENS)
        pitch = clamp(pitch - command.look_delta.y * SENS, -1.45, 1.45)

        var direction := (player.transform.basis * Vector3(command.move.x, 0.0, command.move.y)).normalized()
        var move_speed := 3.4 if command.crouch else 5.6
        var replay_steps := mini(tick_delta, 4)
        for step in replay_steps:
            var replay_delta := physics_step
            player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, 25.0 * replay_delta)
            player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, 25.0 * replay_delta)

            if not player.is_on_floor():
                player.velocity.y -= GRAVITY * replay_delta
            elif step == 0 and command.jump and not command.crouch:
                player.velocity.y = 5.0

            if command.crouch != crouched:
                _set_crouch(command.crouch)
            player.move_and_slide()

    pending_prediction_replay = false
    prediction_replay_tick = 0
    prediction_replay_commands.clear()

    if deferred_prediction_snapshot != null:
        var latest_snapshot := deferred_prediction_snapshot
        deferred_prediction_snapshot = null
        if not dead:
            _start_prediction_replay(latest_snapshot)


func _start_prediction_replay(snapshot: OpenStrikeSnapshot) -> void:
    if snapshot == null or dead:
        return

    var position_correction_needed := OpenStrikeReconciliation.correction_needed(snapshot.position, player.global_position)
    var rotation_correction_needed := OpenStrikeReconciliation.rotation_correction_needed(snapshot.yaw, player.rotation.y, snapshot.pitch, pitch)
    # Velocity can diverge even when the player's position is still inside the
    # positional tolerance (for example after a server-side collision or jump
    # correction). Keep it as an independent reconciliation signal so the next
    # prediction step starts from the same authoritative momentum.
    var velocity_correction_needed := player.velocity.distance_to(snapshot.velocity) > 0.75
    if not position_correction_needed and not rotation_correction_needed and not velocity_correction_needed:
        return

    prediction_replay_position = snapshot.position
    prediction_replay_velocity = snapshot.velocity
    prediction_replay_yaw = snapshot.yaw
    prediction_replay_pitch = snapshot.pitch
    crouched = snapshot.crouched
    _set_crouch(crouched)
    prediction_replay_tick = snapshot.tick
    prediction_replay_commands = prediction.buffer.pending_commands_snapshot()
    pending_prediction_replay = not prediction_replay_commands.is_empty()
    if pending_prediction_replay:
        network_diagnostics.record_prediction_correction()
        return

    if position_correction_needed:
        player.global_position = OpenStrikeReconciliation.corrected_position(snapshot.position, player.global_position, 0.45)
    if velocity_correction_needed:
        player.velocity = OpenStrikeReconciliation.corrected_velocity(snapshot.velocity, player.velocity, 0.5)
    if rotation_correction_needed:
        player.rotation.y = OpenStrikeReconciliation.corrected_angle(snapshot.yaw, player.rotation.y, 0.35)
        pitch = OpenStrikeReconciliation.corrected_angle(snapshot.pitch, pitch, 0.35)


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
            _request_round_outcome(false, "TIMEOUT")
    elif round_state == "POST":
        if round_state_time_left <= 0.0:
            round_number += 1
            _start_round()

func _current_bomb_site() -> String:
    var position := _objective_actor_position()
    if position.distance_to(BOMB_SITE_A) <= BOMB_SITE_RADIUS:
        return "A"
    if position.distance_to(BOMB_SITE_B) <= BOMB_SITE_RADIUS:
        return "B"
    return ""


func set_network_objective_input(peer_id: int, active: bool) -> void:
    if network_session == null or not network_session.is_server:
        return
    if not active:
        if network_objective_peer_id == peer_id:
            network_objective_peer_id = -1
        if network_objective_latched_peer_id == peer_id:
            network_objective_latched_peer_id = -1
            if objective_action != "PLANT" and objective_action != "DEFUSE":
                _clear_objective_action()
        return
    if round_state != "LIVE":
        network_objective_peer_id = -1
        network_objective_latched_peer_id = -1
        return
    if network_objective_latched_peer_id == peer_id:
        return
    # The server owns the interaction lock. A second client cannot replace
    # an active claimant between pickup/plant/defuse ticks; it must wait for
    # the current claimant to release F or disconnect.
    if network_objective_peer_id != -1 and network_objective_peer_id != peer_id:
        return
    network_objective_peer_id = peer_id

func _network_objective_actor() -> Node:
    if network_objective_peer_id <= 0 or network_session == null:
        return null
    var actor = network_session.network_players.get(network_objective_peer_id)
    if actor is OpenStrikeNetworkPlayer and is_instance_valid(actor) and not actor.dead:
        return actor
    network_objective_peer_id = -1
    return null

func _objective_actor_position() -> Vector3:
    var actor := _network_objective_actor()
    if actor != null:
        return actor.global_position
    return player.global_position

func _begin_objective_action() -> void:
    if round_state != "LIVE" or objective_action != "":
        return

    if objective_state == "CARRIED":
        var site := _current_bomb_site()
        if site != "":
            objective_site = site
            objective_action = "PLANT"
            objective_action_peer_id = 0
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
            objective_action_peer_id = 0
            objective_action_time_left = DEFUSE_TIME


func _update_objective(delta: float) -> void:
    if round_state != "LIVE":
        _clear_objective_action()
        network_objective_peer_id = -1
        network_objective_latched_peer_id = -1
        return

    var network_actor := _network_objective_actor()
    if network_actor != null and objective_action == "":
        if objective_state == "CARRIED" and bomb_carrier_peer_id == network_objective_peer_id:
            var network_site := _current_bomb_site()
            if network_site != "":
                objective_site = network_site
                objective_action = "PLANT"
                objective_action_peer_id = network_objective_peer_id
                objective_action_time_left = PLANT_TIME
        elif objective_state == "DROPPED":
            if network_actor.global_position.distance_to(dropped_bomb_position) <= BOMB_PICKUP_RADIUS:
                objective_state = "CARRIED"
                bomb_carrier_peer_id = network_objective_peer_id
                objective_site = ""
                dropped_bomb_position = Vector3.ZERO
                network_objective_latched_peer_id = network_objective_peer_id
        elif objective_state == "PLANTED":
            var network_defuse_site := _current_bomb_site()
            if network_defuse_site == planted_site:
                objective_site = network_defuse_site
                objective_action = "DEFUSE"
                objective_action_peer_id = network_objective_peer_id
                objective_action_time_left = DEFUSE_TIME

    var site := _current_bomb_site()
    var objective_input_active := network_actor != null or Input.is_key_pressed(KEY_F)

    if objective_state == "CARRIED":
        if objective_action == "PLANT":
            if site == "" or site != objective_site or not objective_input_active:
                _clear_objective_action()
            else:
                objective_action_time_left = maxf(0.0, objective_action_time_left - delta)
                if objective_action_time_left <= 0.0:
                    objective_state = "PLANTED"
                    bomb_carrier_peer_id = 0
                    planted_site = site
                    if network_actor != null:
                        network_objective_latched_peer_id = network_objective_peer_id
                    bomb_time_left = BOMB_TIME
                    _clear_objective_action()
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
            _request_round_outcome(true, "BOMB_EXPLODED")
            return

        if objective_action == "DEFUSE":
            if site != planted_site or not objective_input_active:
                _clear_objective_action()
            else:
                objective_action_time_left = maxf(0.0, objective_action_time_left - delta)
                if objective_action_time_left <= 0.0:
                    objective_state = "DEFUSED"
                    _clear_objective_action()
                    if network_actor != null:
                        network_objective_latched_peer_id = network_objective_peer_id
                    _request_round_outcome(false, "PLAYER_DEFUSED")

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

    # Keep reachability checks consistent with actual route construction.
    # A connected nav graph is not sufficient if either endpoint cannot
    # visibly connect to its nearest navigation node.
    if not _navigation_visible(bot.global_position, navigation_points[start_index]):
        return false
    if not _navigation_visible(navigation_points[goal_index], goal):
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
        # The player has taken over the defuse action. Release any bot
        # defuser so it does not remain in DEFUSE state or retain stale
        # progress when the player cancels the action.
        if active_defuser != null or bot_defuse_time_left > 0.0:
            active_defuser = null
            bot_defuse_time_left = 0.0
            bomb_defense_revision += 1
        return

    var site_position := bomb_site_a if planted_site == "A" else bomb_site_b
    if not is_instance_valid(active_defuser) or active_defuser.dead:
        if active_defuser != null or bot_defuse_time_left > 0.0:
            bomb_defense_revision += 1
        active_defuser = null
        bot_defuse_time_left = 0.0

    if active_defuser != null:
        var defuser_distance := active_defuser.global_position.distance_to(site_position)
        if defuser_distance > BOMB_SITE_RADIUS:
            active_defuser = null
            bot_defuse_time_left = 0.0
            bomb_defense_revision += 1

    if active_defuser == null:
        var reachable_bot: Node = null
        var reachable_distance := INF
        for bot in bots:
            if not is_instance_valid(bot) or bot.dead:
                continue
            var distance := bot.global_position.distance_to(site_position)
            if _bot_has_navigation_path(bot, site_position) and distance < reachable_distance:
                reachable_distance = distance
                reachable_bot = bot

        # Never lock the defuse objective to a bot that cannot reach the site.
        # Leave it unassigned until a reachable defender is available.
        if reachable_bot != null:
            active_defuser = reachable_bot
            bot_defuse_time_left = DEFUSE_TIME
            bomb_defense_revision += 1

    if active_defuser != null:
        var defuser_distance := active_defuser.global_position.distance_to(site_position)
        if defuser_distance <= BOMB_SITE_RADIUS:
            bot_defuse_time_left = maxf(0.0, bot_defuse_time_left - delta)
            if bot_defuse_time_left <= 0.0:
                objective_state = "DEFUSED"
                _request_round_outcome(false, "BOT_DEFUSED")


func _update_bomb_visual() -> void:
    if bomb_visual == null:
        return

    var visible_bomb := objective_state == "DROPPED" or objective_state == "PLANTED"
    bomb_visual.visible = visible_bomb
    if bomb_light != null:
        bomb_light.visible = visible_bomb

    if not visible_bomb:
        bomb_visual.scale = Vector3.ONE
        return

    var now_seconds := Time.get_ticks_msec() / 1000.0
    var bomb_position := dropped_bomb_position
    if objective_state == "PLANTED":
        bomb_position = bomb_site_a if planted_site == "A" else bomb_site_b

    var urgency := clampf(1.0 - bomb_time_left / BOMB_TIME, 0.0, 1.0) if objective_state == "PLANTED" else 0.0
    # The dropped objective has a slow idle turn; a planted bomb stays anchored
    # but gains a restrained pulse that accelerates with the countdown.
    if objective_state == "DROPPED":
        bomb_visual.rotation.y = now_seconds * 0.45
        bomb_visual.global_position = bomb_position + Vector3(0.0, 0.35 + sin(now_seconds * 2.0) * 0.035, 0.0)
    else:
        bomb_visual.rotation.y = 0.0
        var pulse_rate := lerpf(2.2, 7.0, urgency)
        var pulse := 1.0 + absf(sin(now_seconds * pulse_rate)) * lerpf(0.025, 0.075, urgency)
        bomb_visual.scale = Vector3.ONE * pulse
        bomb_visual.global_position = bomb_position + Vector3(0.0, 0.35, 0.0)

    var blink_rate := lerpf(1.4, 5.0, urgency)
    var blink_phase := sin(now_seconds * TAU * blink_rate)
    var active_blink := blink_phase > 0.0 if objective_state == "PLANTED" else true
    if bomb_status_material != null:
        bomb_status_material.emission_energy_multiplier = 2.8 if active_blink else 0.12
    if bomb_light != null:
        bomb_light.light_energy = lerpf(1.8, 3.2, urgency) if active_blink else 0.18

func _objective_carrier_label() -> String:
    if objective_state != "CARRIED":
        return ""
    if bomb_carrier_peer_id == 0:
        return "HOST"
    if network_session != null and bomb_carrier_peer_id == multiplayer.get_unique_id():
        return "YOU"
    return "PLAYER #%d" % bomb_carrier_peer_id

func _objective_action_actor_label() -> String:
    if objective_action == "":
        return ""
    if objective_action_peer_id <= 0:
        return "HOST"
    if network_session != null and objective_action_peer_id == multiplayer.get_unique_id():
        return "YOU"
    return "PLAYER #%d" % objective_action_peer_id

func _clear_objective_action() -> void:
    objective_action = ""
    objective_action_peer_id = -1
    objective_action_time_left = 0.0

func _objective_label() -> String:
    if objective_state == "CARRIED":
        var carrier := _objective_carrier_label()
        if objective_action == "PLANT":
            return "BOMB: PLANTING %s %0.1fs — %s" % [objective_site, objective_action_time_left, _objective_action_actor_label()]
        if objective_site != "":
            return "BOMB: CARRIED BY %s — SITE %s — HOLD F" % [carrier, objective_site]
        return "BOMB: CARRIED BY %s — MOVE TO A/B" % carrier
    if objective_state == "DROPPED":
        var local_near := player.global_position.distance_to(dropped_bomb_position) <= BOMB_PICKUP_RADIUS
        if local_near:
            return "BOMB: DROPPED — HOLD F TO RECOVER"
        return "BOMB: DROPPED — RECOVER AT %0.1f, %0.1f" % [dropped_bomb_position.x, dropped_bomb_position.z]
    if objective_state == "PLANTED":
        if objective_action == "DEFUSE":
            return "BOMB: PLANTED %s — DEFUSING %0.1fs — %s" % [planted_site, objective_action_time_left, _objective_action_actor_label()]
        return "BOMB: PLANTED %s — %0.1fs" % [planted_site, bomb_time_left]
    if objective_state == "DEFUSED":
        return "BOMB: DEFUSED"
    if objective_state == "EXPLODED":
        return "BOMB: EXPLODED"
    return "BOMB: NONE"


func _load_weapon_catalog() -> void:
    weapons.clear()
    var seen_ids := {}
    for asset in WEAPON_ASSETS:
        if asset == null or not asset.is_valid():
            push_error("OpenStrike weapon catalog contains an invalid weapon resource.")
            continue
        var weapon_id := String(asset.weapon_id)
        if weapon_id.is_empty() or seen_ids.has(weapon_id):
            push_error("OpenStrike weapon catalog contains a duplicate or empty weapon id: %s" % weapon_id)
            continue
        seen_ids[weapon_id] = true
        weapons.append(asset.to_runtime_dict())

    if weapons.is_empty():
        push_error("OpenStrike weapon catalog is empty; gameplay cannot start safely.")
        return

func _current_weapon() -> Dictionary:
    return weapons[weapon_index]

func _current_speed() -> float:
    if crouched:
        return 2.8
    return float(_current_weapon()["speed"])

func apply_authoritative_network_damage(damage: int) -> bool:
	if dead or damage <= 0 or round_state != "LIVE":
		return false
	health = maxi(0, health - damage)
	if health <= 0:
		dead = true
		respawn_timer = RESPAWN_DELAY
	return true

func _fire() -> void:
    if ammo <= 0:
        _reload()
        return

    var weapon := _current_weapon()
    var result := combat_events.validate_fire(
        round_state,
        dead,
        weapon,
        weapon_index == 1 or primary_owned,
        cooldown,
        ammo,
        null,
        player_team
    )
    if not result.accepted:
        return

    input_sequence = combat_authority.next_input_sequence()
    cooldown = float(weapon["delay"])
    ammo -= 1
    _trigger_muzzle_flash()
    _spawn_shell_casing()
    last_processed_input_sequence = input_sequence
    recoil_kick += float(weapon["recoil"])
    combat_events.advance_tick()
    combat_events.emit_shot("player", str(weapon["id"]), ammo, reserve)

    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var tracer_end: Vector3 = hit.position if not hit.is_empty() else origin + direction * 75.0
    var tracer_color := Color(0.50, 0.88, 1.0) if str(weapon["id"]) == "ar_17" else Color(1.0, 0.68, 0.28)
    _spawn_shot_tracer(origin, tracer_end, tracer_color)
    if not hit.is_empty():
        var impact_normal: Vector3 = hit.get("normal", Vector3.UP)
        _spawn_impact_spark(hit.position, impact_normal, tracer_color)
        var impact_collider = hit.get("collider")
        if impact_collider != null and not impact_collider.has_method("take_damage"):
            _spawn_impact_mark(hit.position, impact_normal, tracer_color)

    if network_session != null and network_session.is_server and network_session.is_online:
        if network_session.process_host_fire(origin, direction, str(weapon["id"]), int(weapon["damage"])):
            return

    if hit and hit.collider.has_method("take_damage"):
        var target_team := str(hit.collider.get("team"))
        if target_team != player_team:
            # Bot eliminations are scored by the bot's `eliminated` signal.
            # Keep this path limited to applying damage to avoid double rewards.
            hit.collider.take_damage(int(weapon["damage"]), "player")
            var target_id := str(hit.collider.get_instance_id())
            combat_events.emit_hit("player", target_id, str(weapon["id"]), int(weapon["damage"]), hit.position, false)
            _show_hit_feedback()

func _spawn_shot_tracer(start_position: Vector3, end_position: Vector3, tint: Color) -> void:
    # A short-lived, emissive streak gives each shot a readable direction cue.
    # It is render-only and deliberately avoids particles, physics, and lights.
    var segment := end_position - start_position
    var length := segment.length()
    if length < 0.15:
        return

    var tracer := MeshInstance3D.new()
    tracer.name = "ShotTracer"
    var tracer_mesh := CylinderMesh.new()
    tracer_mesh.top_radius = 0.014
    tracer_mesh.bottom_radius = 0.014
    tracer_mesh.height = length
    tracer.mesh = tracer_mesh
    tracer.global_position = (start_position + end_position) * 0.5
    tracer.quaternion = Quaternion(Vector3.UP, segment / length)

    var tracer_material := StandardMaterial3D.new()
    tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tracer_material.albedo_color = tint
    tracer_material.emission_enabled = true
    tracer_material.emission = tint
    tracer_material.emission_energy_multiplier = 2.0
    tracer.material_override = tracer_material
    tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(tracer)
    get_tree().create_timer(0.065).timeout.connect(tracer.queue_free)

func _spawn_shell_casing() -> void:
    # A tiny brass casing ejects to the right and fades out. It is a render-only
    # effect: no collision, rigid body, particles, or additional light.
    if not is_instance_valid(camera):
        return
    if shell_casing_material == null:
        shell_casing_material = StandardMaterial3D.new()
        shell_casing_material.albedo_color = Color(0.72, 0.48, 0.16, 1.0)
        shell_casing_material.metallic = 0.72
        shell_casing_material.roughness = 0.3
        shell_casing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var casing := MeshInstance3D.new()
    casing.name = "ShellCasing"
    var casing_mesh := CylinderMesh.new()
    casing_mesh.top_radius = 0.018
    casing_mesh.bottom_radius = 0.022
    casing_mesh.height = 0.085
    casing.mesh = casing_mesh
    casing.material_override = shell_casing_material
    casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var basis := camera.global_transform.basis
    var start := camera.global_position + basis.x * 0.30 - basis.y * 0.22 - basis.z * 0.42
    casing.global_position = start
    casing.global_rotation = camera.global_rotation + Vector3(0.8, 0.4, 0.6)
    add_child(casing)

    var end_position := start + basis.x * 0.72 - basis.y * 0.92 + basis.z * 0.28
    var tween := create_tween().set_parallel(true)
    tween.tween_property(casing, "global_position", end_position, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(casing, "rotation", casing.rotation + Vector3(5.2, 3.6, 7.0), 0.62)
    tween.tween_property(casing, "scale", Vector3.ZERO, 0.22).set_delay(0.40)
    tween.finished.connect(casing.queue_free)

func _spawn_impact_spark(position: Vector3, surface_normal: Vector3, tint: Color) -> void:
    # Tiny short-lived impact flash improves hit readability without particles,
    # dynamic lights, collision, or persistent decals.
    var spark := MeshInstance3D.new()
    spark.name = "ImpactSpark"
    var spark_mesh := SphereMesh.new()
    spark_mesh.radius = 0.055
    spark_mesh.height = 0.11
    spark.mesh = spark_mesh
    var normal := surface_normal.normalized()
    if normal.length_squared() < 0.01:
        normal = Vector3.UP
    spark.global_position = position + normal * 0.035
    spark.scale = Vector3(1.0, 0.8, 1.0)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = tint
    material.emission_enabled = true
    material.emission = tint
    material.emission_energy_multiplier = 2.4
    spark.material_override = material
    spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(spark)
    get_tree().create_timer(0.09).timeout.connect(spark.queue_free)


func _spawn_impact_mark(position: Vector3, surface_normal: Vector3, tint: Color) -> void:
    # A brief, flat scorch ring makes bullet impacts persist long enough to read
    # against concrete and metal. It is render-only, capped by a short lifetime,
    # and never changes collision or gameplay state.
    var normal := surface_normal.normalized()
    if normal.length_squared() < 0.01:
        normal = Vector3.UP

    var mark := MeshInstance3D.new()
    mark.name = "ImpactMark"
    var mark_mesh := CylinderMesh.new()
    mark_mesh.top_radius = 0.075
    mark_mesh.bottom_radius = 0.075
    mark_mesh.height = 0.006
    mark.mesh = mark_mesh
    mark.global_position = position + normal * 0.012
    mark.quaternion = Quaternion(Vector3.UP, normal)
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.025, 0.032, 0.04, 0.78)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 1.0
    mark.material_override = material
    add_child(mark)

    var tween := create_tween()
    tween.tween_property(material, "albedo_color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.finished.connect(mark.queue_free)


func _reload() -> void:
    if ammo >= int(_current_weapon()["mag"]) or reserve <= 0:
        return
    view_weapon_reload_timer = VIEW_WEAPON_RELOAD_DURATION
    var magazine_size := int(_current_weapon()["mag"])
    var amount := mini(magazine_size - ammo, reserve)
    ammo += amount
    reserve -= amount
    combat_events.advance_tick()
    combat_events.emit_reload("player", str(_current_weapon()["id"]), ammo, reserve)

func _switch_weapon() -> void:
    if not primary_owned:
        weapon_index = 1
        _load_weapon_ammo()
        return
    _store_weapon_ammo()
    weapon_index = (weapon_index + 1) % weapons.size()
    _load_weapon_ammo()
    _refresh_view_weapon()

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
        _refresh_view_weapon()
    elif index == 1:
        weapon_index = 1
        ammo = int(weapons[1]["mag"])
        reserve = int(weapons[1]["reserve"])
        cooldown = 0.0
        _refresh_view_weapon()

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

func _hud() -> void:
    # A lightweight HUD card keeps match information readable over bright
    # surfaces while leaving most of the view unobstructed.
    hud_layer = CanvasLayer.new()
    hud_layer.name = "OpenStrikeHUD"
    hud_layer.layer = 10

    var panel := PanelContainer.new()
    panel.name = "MatchInfoPanel"
    panel.position = Vector2(18.0, 18.0)
    panel.custom_minimum_size = Vector2(570.0, 196.0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.045, 0.065, 0.86)
    panel_style.border_color = Color(0.12, 0.72, 0.82, 0.95)
    panel_style.border_width_left = 4
    panel_style.corner_radius_top_left = 8
    panel_style.corner_radius_top_right = 8
    panel_style.corner_radius_bottom_left = 8
    panel_style.corner_radius_bottom_right = 8
    panel_style.content_margin_left = 14.0
    panel_style.content_margin_top = 10.0
    panel_style.content_margin_right = 14.0
    panel_style.content_margin_bottom = 10.0
    panel.add_theme_stylebox_override("panel", panel_style)

    hud = Label.new()
    hud.name = "MatchInfo"
    hud.custom_minimum_size = Vector2(540.0, 176.0)
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.add_theme_font_size_override("font_size", 16)
    hud.add_theme_color_override("font_color", Color(0.90, 0.95, 0.98))
    hud.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
    hud.add_theme_constant_override("shadow_offset_x", 1)
    hud.add_theme_constant_override("shadow_offset_y", 1)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(hud)
    hud_layer.add_child(panel)
    add_child(hud_layer)

func _create_crosshair() -> void:
    # Screen-space combat feedback is layered beneath the reticle and has no
    # physics, particles, or dynamic-light cost.
    crosshair_root = Control.new()
    crosshair_root.name = "OpenStrikeCrosshair"
    crosshair_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    crosshair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(crosshair_root)

    damage_flash = ColorRect.new()
    damage_flash.name = "DamageFlash"
    damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_flash.color = Color(0.72, 0.035, 0.025, 0.0)
    damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    crosshair_root.add_child(damage_flash)

    # Lightweight screen-space edge vignette warns at low health without
    # obscuring the center aim point or adding world effects.
    low_health_vignette = ColorRect.new()
    low_health_vignette.name = "LowHealthVignette"
    low_health_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    low_health_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var vignette_shader := Shader.new()
    vignette_shader.code = """shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.8) = 0.0;
void fragment() {
    float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float edge_mask = 1.0 - smoothstep(0.0, 0.34, edge_distance);
    COLOR = vec4(0.58, 0.018, 0.012, edge_mask * strength);
}
"""
    var vignette_material := ShaderMaterial.new()
    vignette_material.shader = vignette_shader
    vignette_material.set_shader_parameter("strength", 0.0)
    low_health_vignette.material = vignette_material
    crosshair_root.add_child(low_health_vignette)

    hit_marker = Label.new()
    hit_marker.name = "HitMarker"
    hit_marker.text = "×"
    hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hit_marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    hit_marker.position = Vector2(-18.0, -24.0)
    hit_marker.size = Vector2(36.0, 36.0)
    hit_marker.pivot_offset = hit_marker.size * 0.5
    hit_marker.scale = Vector2.ONE
    hit_marker.add_theme_font_size_override("font_size", 32)
    hit_marker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52, 1.0))
    hit_marker.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.95))
    hit_marker.add_theme_constant_override("outline_size", 3)
    hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hit_marker.visible = false
    crosshair_root.add_child(hit_marker)

    # Bottom-center objective progress gives plant/defuse actions a clear,
    # screen-space completion cue without adding world geometry or lights.
    objective_progress_label = Label.new()
    objective_progress_label.name = "ObjectiveProgressLabel"
    objective_progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    objective_progress_label.position = Vector2(-180.0, -142.0)
    objective_progress_label.size = Vector2(360.0, 26.0)
    objective_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    objective_progress_label.add_theme_font_size_override("font_size", 15)
    objective_progress_label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0, 1.0))
    objective_progress_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
    objective_progress_label.add_theme_constant_override("shadow_offset_x", 1)
    objective_progress_label.add_theme_constant_override("shadow_offset_y", 1)
    objective_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    objective_progress_label.visible = false
    crosshair_root.add_child(objective_progress_label)

    objective_progress_bar = ProgressBar.new()
    objective_progress_bar.name = "ObjectiveProgressBar"
    objective_progress_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    objective_progress_bar.position = Vector2(-180.0, -112.0)
    objective_progress_bar.size = Vector2(360.0, 14.0)
    objective_progress_bar.min_value = 0.0
    objective_progress_bar.max_value = 100.0
    objective_progress_bar.show_percentage = false
    objective_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var progress_background := StyleBoxFlat.new()
    progress_background.bg_color = Color(0.015, 0.025, 0.04, 0.88)
    progress_background.border_color = Color(0.38, 0.53, 0.62, 0.9)
    progress_background.set_border_width_all(1)
    progress_background.set_corner_radius_all(3)
    objective_progress_bar.add_theme_stylebox_override("background", progress_background)
    var progress_fill := StyleBoxFlat.new()
    progress_fill.bg_color = Color(0.10, 0.78, 0.88, 0.98)
    progress_fill.set_corner_radius_all(3)
    objective_progress_bar.add_theme_stylebox_override("fill", progress_fill)
    objective_progress_bar.visible = false
    crosshair_root.add_child(objective_progress_bar)

    for index in 5:
        var segment := ColorRect.new()
        segment.name = "ReticlePart%d" % index
        segment.color = Color(0.78, 0.96, 1.0, 0.96) if index < 4 else Color(1.0, 0.68, 0.20, 1.0)
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        crosshair_root.add_child(segment)
        crosshair_segments.append(segment)
    _update_crosshair()



func _update_crosshair() -> void:
    if crosshair_root == null or crosshair_segments.size() < 5:
        return
    crosshair_root.visible = not dead
    if dead:
        return

    var viewport_size := get_viewport().get_visible_rect().size
    var center := viewport_size * 0.5
    var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length() if is_instance_valid(player) else 0.0
    var spread := 5.0 + clampf(horizontal_speed * 1.25, 0.0, 10.0) + clampf(recoil_kick * 16.0, 0.0, 8.0)
    if crouched:
        spread *= 0.72
    var thickness := 2.0
    var length := 9.0

    # Left, right, top, bottom, then a tiny warm center dot.
    crosshair_segments[0].position = center + Vector2(-spread - length, -thickness * 0.5)
    crosshair_segments[0].size = Vector2(length, thickness)
    crosshair_segments[1].position = center + Vector2(spread, -thickness * 0.5)
    crosshair_segments[1].size = Vector2(length, thickness)
    crosshair_segments[2].position = center + Vector2(-thickness * 0.5, -spread - length)
    crosshair_segments[2].size = Vector2(thickness, length)
    crosshair_segments[3].position = center + Vector2(-thickness * 0.5, spread)
    crosshair_segments[3].size = Vector2(thickness, length)
    crosshair_segments[4].position = center - Vector2(1.0, 1.0)
    crosshair_segments[4].size = Vector2(2.0, 2.0)


func _create_elimination_feedback() -> void:
    # A compact kill-confirmation banner reinforces successful eliminations
    # without adding world-space objects or changing combat rules.
    elimination_feedback_label = Label.new()
    elimination_feedback_label.name = "EliminationFeedback"
    elimination_feedback_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    elimination_feedback_label.position = Vector2(-220.0, 92.0)
    elimination_feedback_label.size = Vector2(440.0, 54.0)
    elimination_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    elimination_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    elimination_feedback_label.text = "ELIMINATION  +$%d" % KILL_REWARD
    elimination_feedback_label.add_theme_font_size_override("font_size", 25)
    elimination_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30, 1.0))
    elimination_feedback_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    elimination_feedback_label.add_theme_constant_override("outline_size", 5)
    elimination_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    elimination_feedback_label.visible = false
    hud_layer.add_child(elimination_feedback_label)

func _show_elimination_feedback() -> void:
    elimination_feedback_timer = 1.15
    if elimination_feedback_label == null:
        return
    elimination_feedback_label.text = "ELIMINATION  +$%d" % KILL_REWARD
    elimination_feedback_label.visible = true
    elimination_feedback_label.modulate = Color.WHITE
    elimination_feedback_label.scale = Vector2.ONE

func _update_elimination_feedback(delta: float) -> void:
    if elimination_feedback_label == null:
        return
    elimination_feedback_timer = maxf(0.0, elimination_feedback_timer - delta)
    if elimination_feedback_timer <= 0.0:
        elimination_feedback_label.visible = false
        return
    var progress := clampf(elimination_feedback_timer / 1.15, 0.0, 1.0)
    elimination_feedback_label.modulate.a = minf(1.0, progress * 2.8)
    elimination_feedback_label.scale = Vector2.ONE * (1.0 + 0.10 * (1.0 - progress))

func _create_network_debug_hud() -> void:
    network_debug_hud = Label.new()
    network_debug_hud.position = Vector2(18, 226)
    network_debug_hud.size = Vector2(520, 120)
    network_debug_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    network_debug_hud.add_theme_font_size_override("font_size", 14)
    network_debug_hud.visible = network_debug_visible
    if hud_layer != null:
        hud_layer.add_child(network_debug_hud)
    else:
        add_child(network_debug_hud)

func _show_hit_feedback() -> void:
    hit_feedback_timer = 0.14
    if hit_marker != null:
        hit_marker.visible = true
        hit_marker.modulate.a = 1.0

func _update_combat_feedback() -> void:
    if damage_flash != null:
        var damage_alpha := clampf(damage_feedback_timer / 0.18, 0.0, 1.0) * 0.30
        damage_flash.color = Color(0.72, 0.035, 0.025, damage_alpha)
    if low_health_vignette != null:
        low_health_pulse_time += get_process_delta_time()
        var health_ratio := 1.0 - clampf(float(health) / 55.0, 0.0, 1.0)
        var pulse := 0.82 + 0.18 * sin(low_health_pulse_time * 3.8) if health <= 30 else 1.0
        var strength := clampf(health_ratio * 0.52 * pulse, 0.0, 0.52)
        var vignette_material := low_health_vignette.material as ShaderMaterial
        if vignette_material != null:
            vignette_material.set_shader_parameter("strength", strength if not dead else 0.0)
    if hit_marker != null:
        hit_marker.visible = hit_feedback_timer > 0.0 and not dead
        if hit_marker.visible:
            var hit_progress := clampf(hit_feedback_timer / 0.14, 0.0, 1.0)
            hit_marker.modulate.a = hit_progress
            # A quick scale punch makes confirmed hits readable without
            # adding particles, lights, or persistent scene nodes.
            var hit_scale := 1.0 + 0.55 * hit_progress
            hit_marker.scale = Vector2.ONE * hit_scale
        else:
            hit_marker.scale = Vector2.ONE

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

    hud.text = "ROUND %02d  %s  %03d\nTEAM %s  %02d - %02d    CREDITS $%04d\n%s\n%s\n%s    %s    AMMO %02d / %02d\nHP %03d    ENEMIES %02d\nWASD move   CTRL crouch   SPACE jump   LMB fire   R reload   E switch   F objective   ESC mouse   F3 netgraph" % [
        round_number, phase, ceili(phase_time), player_team, team_score, enemy_score,
        credits, buy_line, _objective_label(), weapon["name"], state, ammo, reserve, health, enemies_alive
    ]
    _update_network_debug_hud()
    _update_objective_progress_ui()

func _update_objective_progress_ui() -> void:
    if objective_progress_bar == null or objective_progress_label == null:
        return
    var label_text := ""
    var progress := 0.0
    var tint := Color(0.10, 0.78, 0.88, 0.98)
    if not dead and round_state == "LIVE":
        if objective_action == "PLANT":
            label_text = "PLANTING SITE %s — HOLD F" % objective_site
            progress = 1.0 - clampf(objective_action_time_left / PLANT_TIME, 0.0, 1.0)
            tint = Color(0.10, 0.78, 0.88, 0.98)
        elif objective_action == "DEFUSE":
            label_text = "DEFUSING SITE %s — HOLD F" % planted_site
            progress = 1.0 - clampf(objective_action_time_left / DEFUSE_TIME, 0.0, 1.0)
            tint = Color(0.28, 0.88, 0.58, 0.98)
        elif objective_state == "PLANTED":
            label_text = "BOMB DETONATION"
            progress = clampf(bomb_time_left / BOMB_TIME, 0.0, 1.0)
            tint = Color(1.0, 0.30, 0.12, 0.98)
    var visible_progress := not label_text.is_empty()
    objective_progress_label.visible = visible_progress
    objective_progress_bar.visible = visible_progress
    if not visible_progress:
        return
    objective_progress_label.text = label_text
    objective_progress_bar.value = progress * 100.0
    var fill_style := objective_progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if fill_style != null:
        fill_style.bg_color = tint

func _update_network_debug_hud() -> void:
    if network_debug_hud == null:
        return
    network_debug_hud.visible = network_debug_visible
    if not network_debug_visible:
        return

    var mode := "OFFLINE"
    if network_session != null and network_session.is_online:
        mode = "SERVER" if network_session.is_server else "CLIENT"
    var diagnostics := network_diagnostics.snapshot()
    var reason_text := ""
    var reasons = diagnostics.get("rejection_reasons", {})
    if reasons is Dictionary and not reasons.is_empty():
        var entries: Array[String] = []
        for reason in reasons.keys():
            entries.append("%s:%d" % [str(reason), int(reasons[reason])])
        entries.sort()
        reason_text = "\nReject reasons: " + ", ".join(entries.slice(0, 4))
    network_debug_hud.text = "NETGRAPH [%s]\nTX %d  RX %d  ACK %d  PENDING %d\nREJECT %d  RXDROP %d  ROSTER %d  GAPS %d  CORR %d  TICK %d%s" % [
        mode,
        int(diagnostics.get("sent_commands", 0)),
        int(diagnostics.get("received_snapshots", 0)),
        int(diagnostics.get("last_acknowledged_sequence", 0)),
        prediction.pending_count(),
        int(diagnostics.get("rejected_inputs", 0)),
        int(diagnostics.get("rejected_snapshots", 0)),
        int(diagnostics.get("malformed_bot_rosters", 0)),
        int(diagnostics.get("snapshot_tick_gaps", 0)),
        int(diagnostics.get("prediction_corrections", 0)),
        int(diagnostics.get("last_snapshot_tick", 0)),
        reason_text
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
    round_outcome_resolved = false
    round_outcome_reason = ""
    processed_elimination_ids.clear()
    objective_state = "CARRIED"
    bomb_carrier_peer_id = 0
    objective_site = ""
    planted_site = ""
    bomb_time_left = 0.0
    _clear_objective_action()
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

func _request_round_outcome(won: bool, reason: String) -> bool:
    # Only the authoritative simulation may resolve a round. Online clients
    # consume the server's round_state/round_won through snapshots.
    if network_session != null and network_session.is_online and not network_session.is_server:
        return false
    if round_state != "LIVE" or round_outcome_resolved:
        return false

    round_outcome_resolved = true
    round_outcome_reason = reason
    _finish_round(won)
    return true

func _finish_round(won: bool) -> void:
    if round_state != "LIVE" or not round_outcome_resolved:
        return
    round_state = "POST"
    round_state_time_left = POST_ROUND_TIME
    _clear_objective_action()
    network_objective_peer_id = -1
    network_objective_latched_peer_id = -1
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
    if not is_instance_valid(bot):
        return
    # Bot deaths enter the same normalized combat-event stream as
    # authoritative network eliminations. Scoring and round-end checks are
    # handled centrally by _on_combat_event to prevent double rewards.
    var weapon_id := str(bot.get("weapon_id"))
    var shooter_id := str(bot.get("last_damage_source_id"))
    if shooter_id.is_empty():
        shooter_id = "player"
    combat_events.emit_elimination(shooter_id, str(bot.get_instance_id()), weapon_id, false)

func _on_combat_event(event: OpenStrikeCombatEvent) -> void:
    if event == null or event.type != OpenStrikeCombatEvent.Type.ELIMINATION:
        return

    var elimination_key := event.shooter_id + ":" + event.target_id
    if processed_elimination_ids.has(elimination_key):
        return
    processed_elimination_ids[elimination_key] = true

    if event.shooter_id == "player":
        credits = mini(MAX_CREDITS, credits + KILL_REWARD)
        _show_elimination_feedback()
    elif network_session != null and network_session.is_server:
        var peer_id := int(event.shooter_id)
        var shooter = network_session.network_players.get(peer_id)
        if shooter is OpenStrikeNetworkPlayer:
            shooter.credits = mini(OpenStrikeNetworkPlayer.MAX_CREDITS, shooter.credits + KILL_REWARD)

    # Bot eliminations are the current RED-team round-elimination source.
    # Network players remain respawnable during LIVE and do not terminate the round here.
    for bot in bots:
        if is_instance_valid(bot) and str(bot.get_instance_id()) == event.target_id:
            enemies_alive = maxi(0, enemies_alive - 1)
            if enemies_alive == 0 and round_state == "LIVE":
                _request_round_outcome(true, "ALL_BOTS_ELIMINATED")
            break

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
    damage_feedback_timer = 0.18
    health = maxi(0, health - amount)
    if health == 0:
        _kill_player()

func _kill_player() -> void:
    if objective_state == "CARRIED":
        objective_state = "DROPPED"
        bomb_carrier_peer_id = 0
        dropped_bomb_position = player.global_position + Vector3(0, 0.15, 0)
        objective_site = ""
        _clear_objective_action()
        network_objective_peer_id = -1
        network_objective_latched_peer_id = -1
        _update_bomb_visual()
    dead = true
    respawn_timer = RESPAWN_DELAY
    player.visible = false
    camera.current = false

func _clear_network_objective_owner(peer_id: int) -> void:
    if peer_id <= 0:
        return
    if objective_action_peer_id == peer_id:
        _clear_objective_action()
    if network_objective_peer_id == peer_id:
        network_objective_peer_id = -1
    if network_objective_latched_peer_id == peer_id:
        network_objective_latched_peer_id = -1

func _drop_network_bomb_for_peer(peer_id: int) -> bool:
    if peer_id <= 0 or bomb_carrier_peer_id != peer_id or objective_state != "CARRIED":
        return false
    var carrier = network_session.network_players.get(peer_id) if network_session != null else null
    if not carrier is OpenStrikeNetworkPlayer:
        return false
    objective_state = "DROPPED"
    bomb_carrier_peer_id = 0
    dropped_bomb_position = carrier.global_position + Vector3(0, 0.15, 0)
    objective_site = ""
    _clear_objective_action()
    network_objective_peer_id = -1
    network_objective_latched_peer_id = -1
    _update_bomb_visual()
    return true

func on_network_player_eliminated(peer_id: int) -> void:
    if peer_id <= 0:
        return
    if _drop_network_bomb_for_peer(peer_id):
        return
    _clear_network_objective_owner(peer_id)

func on_network_player_disconnected(peer_id: int) -> void:
    if peer_id <= 0:
        return
    network_diagnostics.record_peer_disconnected(peer_id)
    if _drop_network_bomb_for_peer(peer_id):
        return
    _clear_network_objective_owner(peer_id)

func _respawn_player() -> void:
    dead = false
    health = MAX_HEALTH
    _spawn_player()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _world() -> void:
    _create_visual_environment()
    _box(Vector3(0,-0.5,0), Vector3(36,1,36), Color(0.18,0.20,0.23))
    _box(Vector3(0,2,-18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(0,2,18), Vector3(36,4,1), Color(0.10,0.12,0.15))
    _box(Vector3(-18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    _box(Vector3(18,2,0), Vector3(1,4,36), Color(0.10,0.12,0.15))
    for p in [Vector3(-7,1,-5), Vector3(6,1,-2), Vector3(-3,1,7), Vector3(10,1,9)]:
        _box(p, Vector3(3,2,2), Color(0.28,0.30,0.33))
    # Additional low cover creates readable lanes and gives the bot cover
    # system more meaningful choices without turning the graybox into a
    # navigation-heavy maze.
    for data in [
        {"p": Vector3(-12,0.65,-7), "s": Vector3(2.8,1.3,1.2)},
        {"p": Vector3(-2,0.65,-8), "s": Vector3(3.4,1.3,1.2)},
        {"p": Vector3(7,0.65,-7), "s": Vector3(2.6,1.3,1.2)},
        {"p": Vector3(-9,0.65,4), "s": Vector3(2.4,1.3,1.4)},
        {"p": Vector3(2,0.65,5), "s": Vector3(3.2,1.3,1.2)},
        {"p": Vector3(11,0.65,4), "s": Vector3(2.4,1.3,1.4)}
    ]:
        _box(data["p"], data["s"], Color(0.22,0.25,0.29))
    _setup_navigation_points()
    _setup_cover_points()
    _create_map_dressing()
    _create_spawn_wayfinding()
    _create_wall_ribs()
    _create_overhead_gantry()
    _create_wall_signage()
    _create_floor_grates()
    _create_cover_visual_details()
    _create_site_beacons()
    _spawn_bots()
    _objective_site(BOMB_SITE_A, "A")
    _objective_site(BOMB_SITE_B, "B")
    _create_bomb_visual()



func _create_spawn_wayfinding() -> void:
    # Large, color-coded deployment signs and floor-edge guides make each
    # team's starting side readable at a glance. All pieces are visual-only.
    var blue := Color(0.12, 0.62, 0.98)
    var red := Color(0.96, 0.24, 0.16)
    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = Color(0.025, 0.045, 0.065)
    panel_material.metallic = 0.28
    panel_material.roughness = 0.72
    var blue_trim := StandardMaterial3D.new()
    blue_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    blue_trim.albedo_color = blue
    blue_trim.emission_enabled = true
    blue_trim.emission = blue * 0.55
    blue_trim.emission_energy_multiplier = 1.15
    var red_trim := StandardMaterial3D.new()
    red_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    red_trim.albedo_color = red
    red_trim.emission_enabled = true
    red_trim.emission = red * 0.55
    red_trim.emission_energy_multiplier = 1.15

    var signs := [
        {"z": 17.38, "text": "BLUE  /  DEPLOYMENT", "color": blue, "trim": blue_trim, "rotation": PI},
        {"z": -17.38, "text": "RED  /  DEPLOYMENT", "color": red, "trim": red_trim, "rotation": 0.0}
    ]
    for spec in signs:
        var z := float(spec["z"])
        _visual_box(Vector3(0.0, 2.65, z), Vector3(7.2, 1.15, 0.10), panel_material)
        _visual_box(Vector3(0.0, 3.25, z - 0.065 if z > 0.0 else z + 0.065), Vector3(7.25, 0.055, 0.035), spec["trim"])
        var label := Label3D.new()
        label.name = str(spec["text"]).replace(" ", "")
        label.text = str(spec["text"])
        label.position = Vector3(0.0, 2.62, z - 0.09 if z > 0.0 else z + 0.09)
        label.rotation.y = float(spec["rotation"])
        label.font_size = 64
        label.pixel_size = 0.012
        label.modulate = spec["color"]
        label.outline_size = 10
        label.outline_modulate = Color(0.01, 0.02, 0.03, 0.98)
        label.shaded = false
        add_child(label)

    # Short colored floor bars point inward from the two starting edges.
    for side in [-1.0, 1.0]:
        _visual_box(Vector3(side * 3.8, 0.018, 14.8), Vector3(0.12, 0.025, 4.8), blue_trim)
        _visual_box(Vector3(side * 3.8, 0.018, -14.8), Vector3(0.12, 0.025, 4.8), red_trim)

func _create_overhead_gantry() -> void:
    # Raised industrial gantry frames the arena silhouette without entering
    # player lanes. Every piece is visual-only and has shadows disabled.
    var beam_material := StandardMaterial3D.new()
    beam_material.albedo_color = Color(0.055, 0.075, 0.095)
    beam_material.metallic = 0.58
    beam_material.roughness = 0.52

    var trim_material := StandardMaterial3D.new()
    trim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    trim_material.albedo_color = Color(0.04, 0.38, 0.52)
    trim_material.emission_enabled = true
    trim_material.emission = Color(0.02, 0.19, 0.30)
    trim_material.emission_energy_multiplier = 0.9

    # Continuous upper rails sit just above the perimeter wall caps.
    for z in [-17.1, 17.1]:
        _visual_box(Vector3(0.0, 4.18, z), Vector3(34.2, 0.18, 0.28), beam_material)
        _visual_box(Vector3(0.0, 4.29, z - signf(z) * 0.15), Vector3(34.2, 0.035, 0.035), trim_material)
    for x in [-17.1, 17.1]:
        _visual_box(Vector3(x, 4.18, 0.0), Vector3(0.28, 0.18, 34.2), beam_material)
        _visual_box(Vector3(x - signf(x) * 0.15, 4.29, 0.0), Vector3(0.035, 0.035, 34.2), trim_material)

    # Repeating short braces create a readable modular frame at low geometry cost.
    for coordinate in range(-12, 13, 8):
        for z in [-16.9, 16.9]:
            _visual_box(Vector3(float(coordinate), 3.98, z), Vector3(0.14, 0.42, 0.14), beam_material)
        for x in [-16.9, 16.9]:
            _visual_box(Vector3(x, 3.98, float(coordinate)), Vector3(0.14, 0.42, 0.14), beam_material)

func _create_wall_ribs() -> void:
    # Vertical steel ribs add depth to the perimeter walls without changing
    # collision, sightlines, navigation, or shadow cost.
    var rib_material := StandardMaterial3D.new()
    rib_material.albedo_color = Color(0.045, 0.065, 0.085)
    rib_material.metallic = 0.42
    rib_material.roughness = 0.58

    var edge_material := StandardMaterial3D.new()
    edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_material.albedo_color = Color(0.035, 0.30, 0.42)
    edge_material.emission_enabled = true
    edge_material.emission = Color(0.02, 0.16, 0.25)
    edge_material.emission_energy_multiplier = 0.75

    for coordinate in [-16.0, -8.0, 0.0, 8.0, 16.0]:
        for wall_z in [-17.43, 17.43]:
            _visual_box(Vector3(coordinate, 1.9, wall_z), Vector3(0.28, 3.45, 0.12), rib_material)
            _visual_box(Vector3(coordinate, 3.62, wall_z - signf(wall_z) * 0.075), Vector3(0.38, 0.055, 0.035), edge_material)
        for wall_x in [-17.43, 17.43]:
            _visual_box(Vector3(wall_x, 1.9, coordinate), Vector3(0.12, 3.45, 0.28), rib_material)
            _visual_box(Vector3(wall_x - signf(wall_x) * 0.075, 3.62, coordinate), Vector3(0.035, 0.055, 0.38), edge_material)

func _create_wall_signage() -> void:
    # Compact sector plaques break up the long perimeter walls and add
    # readable orientation landmarks. All meshes and labels are visual-only.
    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = Color(0.025, 0.045, 0.065)
    panel_material.metallic = 0.38
    panel_material.roughness = 0.66

    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.12, 0.16, 0.20)
    frame_material.metallic = 0.55
    frame_material.roughness = 0.5

    var cyan_material := StandardMaterial3D.new()
    cyan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cyan_material.albedo_color = Color(0.06, 0.58, 0.82)
    cyan_material.emission_enabled = true
    cyan_material.emission = Color(0.025, 0.24, 0.42)
    cyan_material.emission_energy_multiplier = 0.85

    var amber_material := StandardMaterial3D.new()
    amber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_material.albedo_color = Color(0.95, 0.48, 0.12)
    amber_material.emission_enabled = true
    amber_material.emission = Color(0.55, 0.19, 0.035)
    amber_material.emission_energy_multiplier = 0.8

    var plaques := [
        {"x": -11.0, "code": "01", "text": "NORTH  /  ENTRY", "accent": cyan_material},
        {"x": -3.7, "code": "02", "text": "SECTOR  /  A", "accent": amber_material},
        {"x": 3.7, "code": "03", "text": "SECTOR  /  B", "accent": cyan_material},
        {"x": 11.0, "code": "04", "text": "SOUTH  /  EXIT", "accent": amber_material}
    ]
    for side in [-1.0, 1.0]:
        for plaque in plaques:
            var x := float(plaque["x"])
            var z := side * 17.36
            _visual_box(Vector3(x, 2.75, z), Vector3(2.75, 1.12, 0.10), frame_material)
            _visual_box(Vector3(x, 2.75, z - side * 0.065), Vector3(2.58, 0.94, 0.045), panel_material)
            _visual_box(Vector3(x, 3.27, z - side * 0.095), Vector3(2.60, 0.055, 0.025), plaque["accent"])
            _visual_box(Vector3(x - 1.12, 2.75, z - side * 0.095), Vector3(0.045, 0.72, 0.025), plaque["accent"])
            var label := Label3D.new()
            label.name = "WallPlaque_" + str(plaque["code"]) + ("_N" if side < 0.0 else "_S")
            label.text = str(plaque["text"])
            label.position = Vector3(x, 2.73, z - side * 0.105)
            label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            label.font_size = 38
            label.pixel_size = 0.010
            label.modulate = Color(0.78, 0.88, 0.94)
            label.outline_size = 8
            label.outline_modulate = Color(0.01, 0.02, 0.03, 0.98)
            label.shaded = false
            add_child(label)

func _create_floor_grates() -> void:
    # Decorative drainage grates add industrial surface detail at the arena edges.
    # They are mesh-only and intentionally do not affect collision or navigation.
    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.055, 0.075, 0.09)
    frame_material.metallic = 0.62
    frame_material.roughness = 0.58

    var slat_material := StandardMaterial3D.new()
    slat_material.albedo_color = Color(0.19, 0.23, 0.27)
    slat_material.metallic = 0.48
    slat_material.roughness = 0.72

    for x in [-13.0, 13.0]:
        var center := Vector3(x, 0.025, 0.0)
        # Outer rails and end caps.
        _visual_box(center + Vector3(-1.45, 0.0, 0.0), Vector3(0.07, 0.045, 2.0), frame_material)
        _visual_box(center + Vector3(1.45, 0.0, 0.0), Vector3(0.07, 0.045, 2.0), frame_material)
        _visual_box(center + Vector3(0.0, 0.0, -0.97), Vector3(2.9, 0.045, 0.07), frame_material)
        _visual_box(center + Vector3(0.0, 0.0, 0.97), Vector3(2.9, 0.045, 0.07), frame_material)
        # Parallel metal slats sit flush with the floor and remain non-colliding.
        for slat in range(1, 10):
            var offset_x := -1.3 + float(slat) * 0.26
            _visual_box(
                center + Vector3(offset_x, 0.012, 0.0),
                Vector3(0.045, 0.028, 1.82),
                slat_material
            )

    # Small inset service panels near the rear wall break up the empty corners.
    for x in [-10.0, 10.0]:
        _visual_box(Vector3(x, 0.025, -13.0), Vector3(1.5, 0.035, 0.85), frame_material)
        for offset in [-0.42, -0.14, 0.14, 0.42]:
            _visual_box(
                Vector3(x + offset, 0.048, -13.0),
                Vector3(0.035, 0.018, 0.72),
                slat_material
            )

func _create_cover_visual_details() -> void:
    # Visual-only face plates make the existing cover read as modular arena
    # equipment. They sit just outside the collision boxes and add no physics.
    var plate_material := StandardMaterial3D.new()
    plate_material.albedo_color = Color(0.065, 0.085, 0.105)
    plate_material.metallic = 0.32
    plate_material.roughness = 0.68

    var trim_material := StandardMaterial3D.new()
    trim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    trim_material.albedo_color = Color(0.08, 0.48, 0.62)
    trim_material.emission_enabled = true
    trim_material.emission = Color(0.025, 0.22, 0.34)
    trim_material.emission_energy_multiplier = 0.8

    var cover_blocks := [
        {"p": Vector3(-7.0, 1.0, -5.0), "s": Vector3(3.0, 2.0, 2.0)},
        {"p": Vector3(6.0, 1.0, -2.0), "s": Vector3(3.0, 2.0, 2.0)},
        {"p": Vector3(-3.0, 1.0, 7.0), "s": Vector3(3.0, 2.0, 2.0)},
        {"p": Vector3(10.0, 1.0, 9.0), "s": Vector3(3.0, 2.0, 2.0)},
        {"p": Vector3(-12.0, 0.65, -7.0), "s": Vector3(2.8, 1.3, 1.2)},
        {"p": Vector3(-2.0, 0.65, -8.0), "s": Vector3(3.4, 1.3, 1.2)},
        {"p": Vector3(7.0, 0.65, -7.0), "s": Vector3(2.6, 1.3, 1.2)},
        {"p": Vector3(-9.0, 0.65, 4.0), "s": Vector3(2.4, 1.3, 1.4)},
        {"p": Vector3(2.0, 0.65, 5.0), "s": Vector3(3.2, 1.3, 1.2)},
        {"p": Vector3(11.0, 0.65, 4.0), "s": Vector3(2.4, 1.3, 1.4)}
    ]

    for data in cover_blocks:
        var pos: Vector3 = data["p"]
        var size: Vector3 = data["s"]
        var panel_width := maxf(0.45, size.x * 0.52)
        var panel_height := maxf(0.30, size.y * 0.38)
        var panel_center := pos + Vector3(0.0, size.y * 0.06, size.z * 0.5 + 0.025)
        _visual_box(panel_center, Vector3(panel_width, panel_height, 0.045), plate_material)
        _visual_box(
            panel_center + Vector3(0.0, panel_height * 0.5 - 0.025, 0.03),
            Vector3(panel_width + 0.08, 0.035, 0.025),
            trim_material
        )
        for side in [-1.0, 1.0]:
            _visual_box(
                panel_center + Vector3(side * (panel_width * 0.5 - 0.055), 0.0, 0.03),
                Vector3(0.035, panel_height * 0.72, 0.025),
                trim_material
            )

func _create_visual_environment() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "OpenStrikeWorldEnvironment"
    var environment := Environment.new()
    # Procedural sky gives the arena a real horizon and a consistent cool
    # daylight gradient while staying asset-free and compatible with GLES3.
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.055, 0.12, 0.22)
    sky_material.sky_horizon_color = Color(0.42, 0.53, 0.64)
    sky_material.ground_bottom_color = Color(0.075, 0.09, 0.11)
    sky_material.ground_horizon_color = Color(0.28, 0.34, 0.40)
    sky_material.sun_angle_max = 18.0
    sky_material.use_debanding = true
    sky.sky_material = sky_material
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.62
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    # A light atmospheric haze softens distant wall edges while keeping the
    # compact arena readable; restrained grading separates cool concrete
    # from the cyan/amber objective accents.
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.16, 0.22, 0.30)
    environment.fog_density = 0.004
    environment.fog_sky_affect = 0.08
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 1.0
    environment.adjustment_contrast = 1.04
    environment.adjustment_saturation = 1.08
    environment_node.environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.name = "MapKeyLight"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(0.80, 0.87, 1.0)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)

    # Emissive perimeter strips add a restrained industrial silhouette without
    # spawning extra dynamic lights or affecting collision/navigation.
    var perimeter_strip := StandardMaterial3D.new()
    perimeter_strip.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    perimeter_strip.albedo_color = Color(0.05, 0.34, 0.48)
    perimeter_strip.emission_enabled = true
    perimeter_strip.emission = Color(0.025, 0.30, 0.48)
    perimeter_strip.emission_energy_multiplier = 1.35
    var perimeter_warning := StandardMaterial3D.new()
    perimeter_warning.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    perimeter_warning.albedo_color = Color(0.56, 0.29, 0.08)
    perimeter_warning.emission_enabled = true
    perimeter_warning.emission = Color(0.60, 0.22, 0.035)
    perimeter_warning.emission_energy_multiplier = 1.1
    for x in range(-14, 15, 7):
        _visual_box(Vector3(float(x), 3.55, -17.40), Vector3(3.0, 0.045, 0.055), perimeter_strip)
        _visual_box(Vector3(float(x), 3.55, 17.40), Vector3(3.0, 0.045, 0.055), perimeter_strip)
    for z in [-14.0, 0.0, 14.0]:
        _visual_box(Vector3(-17.40, 3.55, z), Vector3(0.055, 0.045, 3.0), perimeter_warning)
        _visual_box(Vector3(17.40, 3.55, z), Vector3(0.055, 0.045, 3.0), perimeter_warning)

func _create_map_dressing() -> void:
    # Low-cost, non-colliding markings improve map readability without
    # changing movement, cover, or bot navigation.
    var lane_material := StandardMaterial3D.new()
    lane_material.albedo_color = Color(0.12, 0.48, 0.62)
    lane_material.roughness = 0.82
    var warning_material := StandardMaterial3D.new()
    warning_material.albedo_color = Color(0.92, 0.58, 0.18)
    warning_material.roughness = 0.78

    for x in [-15.0, 15.0]:
        _visual_box(Vector3(x, 0.012, 0.0), Vector3(0.10, 0.025, 31.0), lane_material)
    for z in [-15.0, 15.0]:
        _visual_box(Vector3(0.0, 0.012, z), Vector3(31.0, 0.025, 0.10), lane_material)

    # Subtle tactical lane dashes; visual only.
    for z in range(-12, 13, 4):
        _visual_box(Vector3(0.0, 0.014, float(z)), Vector3(2.4, 0.028, 0.07), lane_material)

    # Amber corner markers around both objective zones.
    for site_pos in [BOMB_SITE_A, BOMB_SITE_B]:
        for offset in [
            Vector3(-2.8, 0.025, -2.8), Vector3(2.8, 0.025, -2.8),
            Vector3(-2.8, 0.025, 2.8), Vector3(2.8, 0.025, 2.8)
        ]:
            _visual_box(site_pos + offset, Vector3(0.65, 0.035, 0.10), warning_material)

    # Thin illuminated-looking trims on the existing cover blocks.
    for p in [
        Vector3(-7.0, 2.04, -5.0), Vector3(6.0, 2.04, -2.0),
        Vector3(-3.0, 2.04, 7.0), Vector3(10.0, 2.04, 9.0)
    ]:
        _visual_box(p, Vector3(2.5, 0.045, 0.06), warning_material)

    # Add a restrained industrial arena finish using visual-only geometry.
    # These details do not add collision or alter combat/navigation.
    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = Color(0.075, 0.105, 0.14)
    panel_material.metallic = 0.28
    panel_material.roughness = 0.62
    var stripe_material := StandardMaterial3D.new()
    stripe_material.albedo_color = Color(0.88, 0.64, 0.22)
    stripe_material.roughness = 0.7

    # Wall-mounted segmented panels break up the large flat perimeter walls.
    for x in range(-14, 15, 4):
        _visual_box(Vector3(float(x), 1.35, -17.43), Vector3(2.6, 1.7, 0.06), panel_material)
        _visual_box(Vector3(float(x), 1.35, 17.43), Vector3(2.6, 1.7, 0.06), panel_material)
    for z in range(-14, 15, 4):
        _visual_box(Vector3(-17.43, 1.35, float(z)), Vector3(0.06, 1.7, 2.6), panel_material)
        _visual_box(Vector3(17.43, 1.35, float(z)), Vector3(0.06, 1.7, 2.6), panel_material)

    # Short hazard stripes identify exposed cover edges.
    for data in [
        {"p": Vector3(-12.0, 1.315, -7.0), "s": Vector3(0.34, 0.025, 1.05)},
        {"p": Vector3(-2.0, 1.315, -8.0), "s": Vector3(0.34, 0.025, 1.05)},
        {"p": Vector3(7.0, 1.315, -7.0), "s": Vector3(0.34, 0.025, 1.05)},
        {"p": Vector3(-9.0, 1.315, 4.0), "s": Vector3(0.34, 0.025, 1.05)},
        {"p": Vector3(2.0, 1.315, 5.0), "s": Vector3(0.34, 0.025, 1.05)},
        {"p": Vector3(11.0, 1.315, 4.0), "s": Vector3(0.34, 0.025, 1.05)}
    ]:
        _visual_box(data["p"], data["s"], stripe_material)

    # Objective-site concentric floor rings and directional approach marks.
    for site_pos in [BOMB_SITE_A, BOMB_SITE_B]:
        var ring := MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = BOMB_SITE_RADIUS + 0.24
        ring_mesh.bottom_radius = BOMB_SITE_RADIUS + 0.24
        ring_mesh.height = 0.025
        ring.position = site_pos + Vector3(0.0, -0.055, 0.0)
        ring.mesh = ring_mesh
        ring.material_override = panel_material
        ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(ring)
        for side in [-1.0, 1.0]:
            _visual_box(site_pos + Vector3(side * 3.8, 0.02, 0.0), Vector3(0.75, 0.035, 0.12), stripe_material)
            _visual_box(site_pos + Vector3(0.0, 0.02, side * 3.8), Vector3(0.12, 0.035, 0.75), stripe_material)

    # Team-side floor identifiers and subtle modular floor seams.
    # These marks are visual-only and deliberately avoid collision changes.
    var blue_material := StandardMaterial3D.new()
    blue_material.albedo_color = Color(0.08, 0.42, 0.78)
    blue_material.roughness = 0.86
    var red_material := StandardMaterial3D.new()
    red_material.albedo_color = Color(0.72, 0.16, 0.12)
    red_material.roughness = 0.86
    var seam_material := StandardMaterial3D.new()
    seam_material.albedo_color = Color(0.12, 0.15, 0.18)
    seam_material.roughness = 0.94

    # Spawn-side bands make team orientation easier to read on approach.
    for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
        _visual_box(Vector3(x, 0.018, 14.2), Vector3(1.6, 0.025, 0.12), blue_material)
        _visual_box(Vector3(x, 0.018, -14.2), Vector3(1.6, 0.025, 0.12), red_material)

    # Modular seams break up the large concrete floor while staying subtle.
    for z in range(-12, 13, 6):
        _visual_box(Vector3(-9.0, 0.009, float(z)), Vector3(0.035, 0.018, 24.0), seam_material)
        _visual_box(Vector3(9.0, 0.009, float(z)), Vector3(0.035, 0.018, 24.0), seam_material)

    # Short approach chevrons orient players toward each objective site.
    for site_pos in [BOMB_SITE_A, BOMB_SITE_B]:
        var approach_z := 1.0 if site_pos.z < 0.0 else -1.0
        for step in range(3):
            var distance := 5.0 + float(step) * 1.5
            _visual_box(
                site_pos + Vector3(0.0, 0.016, approach_z * distance),
                Vector3(1.1 - float(step) * 0.16, 0.025, 0.10),
                warning_material
            )

func _create_site_beacons() -> void:
    # Small emissive pylons make both bomb sites readable from a distance.
    # They are visual-only: no collision, navigation, or gameplay changes.
    var site_specs := [
        {"position": BOMB_SITE_A, "color": Color(0.08, 0.72, 0.96)},
        {"position": BOMB_SITE_B, "color": Color(1.0, 0.48, 0.12)}
    ]
    for spec in site_specs:
        var site_position: Vector3 = spec["position"]
        var site_color: Color = spec["color"]
        var beacon_material := StandardMaterial3D.new()
        beacon_material.albedo_color = site_color.darkened(0.58)
        beacon_material.metallic = 0.35
        beacon_material.roughness = 0.38
        beacon_material.emission_enabled = true
        beacon_material.emission = site_color
        beacon_material.emission_energy_multiplier = 1.25

        var trim_material := StandardMaterial3D.new()
        trim_material.albedo_color = site_color
        trim_material.emission_enabled = true
        trim_material.emission = site_color
        trim_material.emission_energy_multiplier = 1.8
        trim_material.roughness = 0.3

        for offset in [
            Vector3(-2.55, 0.0, -2.55), Vector3(2.55, 0.0, -2.55),
            Vector3(-2.55, 0.0, 2.55), Vector3(2.55, 0.0, 2.55)
        ]:
            _visual_box(site_position + offset + Vector3(0.0, 0.43, 0.0), Vector3(0.16, 0.86, 0.16), beacon_material)
            _visual_box(site_position + offset + Vector3(0.0, 0.91, 0.0), Vector3(0.28, 0.10, 0.28), trim_material)

        # A compact center marker adds a distinct visual anchor without a light source.
        _visual_box(site_position + Vector3(0.0, 0.07, 0.0), Vector3(0.44, 0.08, 0.44), trim_material)

        # Floating, billboarded site signage stays legible from every approach.
        # Label3D is render-only and adds no collision, lights, or navigation cost.
        var site_label := Label3D.new()
        site_label.name = "SiteSign_" + ("A" if site_position == BOMB_SITE_A else "B")
        site_label.text = "SITE " + ("A  /  ALPHA" if site_position == BOMB_SITE_A else "B  /  BRAVO")
        site_label.position = site_position + Vector3(0.0, 2.35, 0.0)
        site_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        site_label.font_size = 56
        site_label.pixel_size = 0.012
        site_label.modulate = site_color
        site_label.outline_size = 10
        site_label.outline_modulate = Color(0.015, 0.025, 0.04, 0.96)
        site_label.no_depth_test = false
        add_child(site_label)

func _visual_box(pos: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh_instance)

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

    # A compact status LED makes the objective readable at close range. Its
    # emission is driven by the planted-bomb timer below; no particles or
    # additional lights are needed.
    var status_led := MeshInstance3D.new()
    status_led.name = "BombStatusLED"
    var led_mesh := SphereMesh.new()
    led_mesh.radius = 0.055
    led_mesh.height = 0.11
    status_led.mesh = led_mesh
    status_led.position = Vector3(0.0, 0.205, 0.0)
    bomb_status_material = StandardMaterial3D.new()
    bomb_status_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bomb_status_material.albedo_color = Color(1.0, 0.18, 0.06)
    bomb_status_material.emission_enabled = true
    bomb_status_material.emission = Color(1.0, 0.12, 0.025)
    bomb_status_material.emission_energy_multiplier = 2.8
    status_led.material_override = bomb_status_material
    status_led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bomb_visual.add_child(status_led)

    bomb_light = OmniLight3D.new()
    bomb_light.name = "BombLight"
    bomb_light.light_color = Color(1.0, 0.2, 0.08, 1.0)
    bomb_light.omni_range = 3.5
    bomb_light.light_energy = 2.5
    bomb_light.visible = false
    bomb_visual.add_child(bomb_light)

func _objective_site(pos: Vector3, label: String) -> void:
    # Color-coded objective zones improve wayfinding while keeping the arena
    # lightweight: the marker and text are visual-only and add no collision.
    var is_site_a := label == "A"
    var site_color := Color(1.0, 0.62, 0.18) if is_site_a else Color(0.12, 0.78, 0.96)
    var marker := MeshInstance3D.new()
    marker.name = "ObjectiveZone" + label
    marker.position = pos
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = BOMB_SITE_RADIUS
    cylinder.bottom_radius = BOMB_SITE_RADIUS
    cylinder.height = 0.08
    marker.mesh = cylinder
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(site_color.r, site_color.g, site_color.b, 0.20)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.roughness = 0.9
    marker.material_override = mat
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marker)

    var site_label := Label3D.new()
    site_label.name = "ObjectiveLabel" + label
    site_label.text = "SITE " + label
    site_label.position = pos + Vector3(0, 0.42, 0)
    site_label.font_size = 56
    site_label.pixel_size = 0.012
    site_label.modulate = site_color
    site_label.outline_modulate = Color(0.015, 0.025, 0.04, 0.98)
    site_label.outline_size = 10
    site_label.shaded = false
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
        if _navigation_visible(start, goal):
            return [goal]
        var start_to_node_visible := _navigation_visible(start, points[start_index])
        var node_to_goal_visible := _navigation_visible(points[start_index], goal)
        if start_to_node_visible and node_to_goal_visible:
            return [points[start_index], goal]
        return []

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
            if route.is_empty():
                return []
            if not _navigation_visible(start, route[0]):
                return []
            if route[route.size() - 1].distance_to(goal) > WAYPOINT_REACHED:
                if not _navigation_visible(route[route.size() - 1], goal):
                    return []
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
            if str(other.state) == "PEEK":
                var other_cover_index := int(other.get("cover_index"))
                if other_cover_index >= 0 and other_cover_index < cover_points.size():
                    var other_cover: Vector3 = cover_points[other_cover_index]["cover"]
                    if other_cover.distance_to(cover_position) < 2.5:
                        occupied = true
                        break
            if str(other.state) == "REPOSITION" and other.combat_reposition_goal != Vector3.ZERO:
                if other.combat_reposition_goal.distance_to(cover_position) < 2.5:
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

func _select_bot_site_cover(bot: Node, site_position: Vector3, player_position: Vector3, role: String) -> Vector3:
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
        if not _bot_has_navigation_path(bot, cover_position):
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

func _configure_bot_count_from_command_line() -> void:
    bot_count = BOT_COUNT
    for arg_value in OS.get_cmdline_user_args():
        var arg := str(arg_value).strip_edges()
        if not arg.begins_with("--bots="):
            continue
        var raw_count := arg.trim_prefix("--bots=").strip_edges()
        if raw_count.is_empty() or not raw_count.is_valid_int():
            push_error("OpenStrike: --bots must be an integer in the range 0..%d." % MAX_BOT_COUNT)
            return
        bot_count = clampi(int(raw_count), 0, MAX_BOT_COUNT)
        return

func _create_bot(index: int) -> CharacterBody3D:
    var bot := CharacterBody3D.new()
    bot.set_script(load("res://bot.gd"))
    bot.position = red_spawn_points[index % red_spawn_points.size()]
    bot.set("team", enemy_team)
    bot.set("network_bot_id", index + 1)
    bot.set("role", "DEFENDER_A" if index == 0 else ("DEFENDER_B" if index == 1 else "ROAMER"))
    bot.set("combat_slot", index)

    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 2.0
    capsule.radius = 0.42
    mesh.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.24, 0.085, 0.075)
    mat.roughness = 0.88
    mesh.material_override = mat

    # Lightweight layered silhouette: vest, head, helmet and team identifier.
    var vest := MeshInstance3D.new()
    var vest_mesh := BoxMesh.new()
    vest_mesh.size = Vector3(0.58, 0.48, 0.34)
    vest.mesh = vest_mesh
    vest.position = Vector3(0.0, 0.10, -0.015)
    var vest_material := StandardMaterial3D.new()
    vest_material.albedo_color = Color(0.34, 0.12, 0.09)
    vest_material.roughness = 0.92
    vest.material_override = vest_material
    vest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.22
    head_mesh.height = 0.44
    head.mesh = head_mesh
    head.position = Vector3(0.0, 0.64, 0.0)
    var head_material := StandardMaterial3D.new()
    head_material.albedo_color = Color(0.48, 0.34, 0.25)
    head_material.roughness = 0.95
    head.material_override = head_material
    head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var helmet := MeshInstance3D.new()
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.245
    helmet_mesh.height = 0.30
    helmet.mesh = helmet_mesh
    helmet.position = Vector3(0.0, 0.88, 0.0)
    var helmet_material := StandardMaterial3D.new()
    helmet_material.albedo_color = Color(0.12, 0.16, 0.19)
    helmet_material.metallic = 0.12
    helmet_material.roughness = 0.72
    helmet.material_override = helmet_material
    helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var team_band := MeshInstance3D.new()
    var band_mesh := BoxMesh.new()
    band_mesh.size = Vector3(0.62, 0.075, 0.36)
    team_band.mesh = band_mesh
    team_band.position = Vector3(0.0, 0.30, -0.20)
    var band_material := StandardMaterial3D.new()
    band_material.albedo_color = Color(0.95, 0.28, 0.12)
    band_material.emission_enabled = true
    band_material.emission = Color(0.65, 0.08, 0.025)
    band_material.emission_energy_multiplier = 0.18
    team_band.material_override = band_material
    team_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var shape := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.height = 2.0
    capsule_shape.radius = 0.42
    shape.shape = capsule_shape

    # Extra low-poly armor pieces give bots a clearer soldier silhouette.
    # These are render-only meshes: the original capsule remains the sole collider.
    var armor_material := StandardMaterial3D.new()
    armor_material.albedo_color = Color(0.16, 0.20, 0.23)
    armor_material.metallic = 0.12
    armor_material.roughness = 0.82
    var dark_material := StandardMaterial3D.new()
    dark_material.albedo_color = Color(0.055, 0.065, 0.075)
    dark_material.roughness = 0.96

    var left_shoulder := _bot_detail(Vector3(0.25, 0.22, 0.30), Vector3(-0.36, 0.22, 0.0), armor_material)
    var right_shoulder := _bot_detail(Vector3(0.25, 0.22, 0.30), Vector3(0.36, 0.22, 0.0), armor_material)
    var left_arm := _bot_detail(Vector3(0.18, 0.48, 0.20), Vector3(-0.39, -0.13, -0.015), dark_material)
    var right_arm := _bot_detail(Vector3(0.18, 0.48, 0.20), Vector3(0.39, -0.13, -0.015), dark_material)
    var left_leg := _bot_detail(Vector3(0.24, 0.48, 0.28), Vector3(-0.17, -0.63, 0.015), armor_material)
    var right_leg := _bot_detail(Vector3(0.24, 0.48, 0.28), Vector3(0.17, -0.63, 0.015), armor_material)
    var backpack := _bot_detail(Vector3(0.42, 0.52, 0.20), Vector3(0.0, 0.02, 0.25), dark_material)
    var chest_rig := _bot_detail(Vector3(0.48, 0.12, 0.36), Vector3(0.0, 0.16, -0.205), armor_material)

    # Compact, render-only rifle silhouette and utility details make enemy
    # units read as armed combatants instead of capsule-shaped targets.
    var weapon_material := StandardMaterial3D.new()
    weapon_material.albedo_color = Color(0.045, 0.055, 0.065)
    weapon_material.metallic = 0.38
    weapon_material.roughness = 0.62
    var weapon_accent := StandardMaterial3D.new()
    weapon_accent.albedo_color = Color(0.76, 0.28, 0.12)
    weapon_accent.roughness = 0.72
    var bot_rifle_body := _bot_detail(Vector3(0.16, 0.14, 0.68), Vector3(0.18, -0.03, -0.34), weapon_material)
    var bot_rifle_barrel := _bot_detail(Vector3(0.065, 0.065, 0.42), Vector3(0.18, 0.0, -0.84), weapon_material)
    var bot_rifle_stock := _bot_detail(Vector3(0.13, 0.13, 0.25), Vector3(0.18, -0.06, 0.12), weapon_material)
    var bot_rifle_magazine := _bot_detail(Vector3(0.095, 0.23, 0.13), Vector3(0.18, -0.21, -0.30), weapon_material)
    var bot_rifle_sight := _bot_detail(Vector3(0.075, 0.065, 0.12), Vector3(0.18, 0.105, -0.36), weapon_accent)
    var left_pouch := _bot_detail(Vector3(0.16, 0.19, 0.11), Vector3(-0.20, -0.02, -0.25), dark_material)
    var right_pouch := _bot_detail(Vector3(0.16, 0.19, 0.11), Vector3(0.20, -0.02, -0.25), dark_material)
    var shoulder_mark := _bot_detail(Vector3(0.07, 0.15, 0.18), Vector3(-0.47, 0.24, -0.02), weapon_accent)

    bot.add_child(mesh)
    bot.add_child(vest)
    bot.add_child(head)
    bot.add_child(helmet)
    bot.add_child(team_band)
    bot.add_child(left_shoulder)
    bot.add_child(right_shoulder)
    bot.add_child(left_arm)
    bot.add_child(right_arm)
    bot.add_child(left_leg)
    bot.add_child(right_leg)
    bot.add_child(backpack)
    bot.add_child(chest_rig)
    bot.add_child(bot_rifle_body)
    bot.add_child(bot_rifle_barrel)
    bot.add_child(bot_rifle_stock)
    bot.add_child(bot_rifle_magazine)
    bot.add_child(bot_rifle_sight)
    bot.add_child(left_pouch)
    bot.add_child(right_pouch)
    bot.add_child(shoulder_mark)
    bot.add_child(shape)
    bot.add_to_group("bots")
    add_child(bot)
    bot.eliminated.connect(_on_enemy_eliminated)
    return bot

func _bot_detail(size: Vector3, detail_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var detail := MeshInstance3D.new()
    var detail_mesh := BoxMesh.new()
    detail_mesh.size = size
    detail.mesh = detail_mesh
    detail.position = detail_position
    detail.material_override = material
    detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return detail

func _spawn_bots() -> void:
    bots.clear()
    for i in bot_count:
        bots.append(_create_bot(i))

func configure_network_bot_count(target_count: int) -> bool:
    if network_session == null or not network_session.is_online or network_session.is_server:
        return false
    var target := clampi(target_count, 0, MAX_BOT_COUNT)
    if bots.size() == target:
        bot_count = target
        return false
    bot_count = target
    while bots.size() > target:
        var bot := bots.pop_back()
        if is_instance_valid(bot):
            bot.queue_free()
    while bots.size() < target:
        bots.append(_create_bot(bots.size()))
    for i in bots.size():
        var bot = bots[i]
        if not is_instance_valid(bot):
            continue
        bot.set("network_bot_id", i + 1)
        bot.set("combat_slot", i)
    return true

func _player() -> void:
    player = CharacterBody3D.new()
    player.name = "LocalPlayer"
    player.position = blue_spawn_points[1]

    player_shape = CollisionShape3D.new()
    player_capsule = CapsuleShape3D.new()
    player_capsule.height = STAND_HEIGHT
    player_capsule.radius = 0.35
    player_shape.shape = player_capsule
    player.add_child(player_shape)

    camera = Camera3D.new()
    camera.name = "PlayerCamera"
    camera.position = Vector3(0.0, STAND_CAMERA_Y, 0.0)
    camera.current = true
    player.add_child(camera)

    _create_view_weapon()
    add_child(player)

func _create_view_weapon() -> void:
    view_weapon_root = Node3D.new()
    view_weapon_root.name = "FirstPersonWeapon"
    view_weapon_root.position = view_weapon_base_position
    camera.add_child(view_weapon_root)
    _refresh_view_weapon()

func _refresh_view_weapon() -> void:
    if view_weapon_root == null:
        return
    for child in view_weapon_root.get_children():
        child.queue_free()

    var is_rifle := str(_current_weapon().get("id", "")) == "ar_17"
    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.12, 0.15, 0.18) if is_rifle else Color(0.17, 0.19, 0.21)
    body_material.metallic = 0.42
    body_material.roughness = 0.48

    var accent_material := StandardMaterial3D.new()
    accent_material.albedo_color = Color(0.10, 0.56, 0.67) if is_rifle else Color(0.84, 0.47, 0.16)
    accent_material.metallic = 0.22
    accent_material.roughness = 0.52

    var grip_material := StandardMaterial3D.new()
    grip_material.albedo_color = Color(0.055, 0.065, 0.075)
    grip_material.roughness = 0.94

    # First-person sleeves and gloves ground the weapon in the player's view.
    # These are low-poly render-only meshes with shadows disabled.
    var sleeve_material := StandardMaterial3D.new()
    sleeve_material.albedo_color = Color(0.12, 0.17, 0.16) if is_rifle else Color(0.16, 0.17, 0.15)
    sleeve_material.roughness = 0.96
    var cuff_material := StandardMaterial3D.new()
    cuff_material.albedo_color = Color(0.075, 0.09, 0.085)
    cuff_material.roughness = 0.98
    var glove_material := StandardMaterial3D.new()
    glove_material.albedo_color = Color(0.055, 0.065, 0.06)
    glove_material.roughness = 0.98

    # Support arm reaches forward under the fore-end; trigger arm sits lower
    # and behind the grip so the silhouette does not cover the sights.
    _view_box(Vector3(-0.22, -0.23, 0.19), Vector3(0.22, 0.23, 0.46), sleeve_material)
    _view_box(Vector3(-0.17, -0.14, -0.035), Vector3(0.19, 0.18, 0.38), sleeve_material)
    _view_box(Vector3(-0.12, -0.075, -0.205), Vector3(0.20, 0.13, 0.22), glove_material)
    _view_box(Vector3(-0.12, -0.075, -0.095), Vector3(0.22, 0.045, 0.07), cuff_material)
    _view_box(Vector3(0.25, -0.27, 0.22), Vector3(0.22, 0.24, 0.42), sleeve_material)
    _view_box(Vector3(0.20, -0.16, 0.015), Vector3(0.19, 0.18, 0.35), sleeve_material)
    _view_box(Vector3(0.12, -0.075, -0.105), Vector3(0.18, 0.15, 0.20), glove_material)
    _view_box(Vector3(0.20, -0.075, 0.005), Vector3(0.20, 0.045, 0.07), cuff_material)

    _view_box(Vector3(0.0, 0.0, 0.0), Vector3(0.16, 0.13, 0.40 if is_rifle else 0.25), body_material)
    _view_box(Vector3(0.0, 0.015, -0.26 if is_rifle else -0.17), Vector3(0.085, 0.085, 0.34 if is_rifle else 0.19), body_material)
    _view_box(Vector3(0.0, 0.09, -0.045), Vector3(0.09, 0.055, 0.19 if is_rifle else 0.10), accent_material)
    _view_box(Vector3(0.0, 0.105, 0.055), Vector3(0.12, 0.055, 0.16 if is_rifle else 0.09), grip_material)
    _view_box(Vector3(0.025, -0.13, 0.055), Vector3(0.105, 0.22 if is_rifle else 0.17, 0.13), grip_material)
    _view_box(Vector3(0.0, -0.13, 0.005), Vector3(0.12, 0.18, 0.13), body_material)
    if is_rifle:
        _view_box(Vector3(0.0, -0.005, 0.30), Vector3(0.13, 0.12, 0.28), grip_material)
        _view_box(Vector3(0.0, 0.14, -0.02), Vector3(0.09, 0.07, 0.10), accent_material)
        # Low-poly rail, iron sights and a distinct barrel give the rifle a
        # clearer silhouette without adding physics or shadow cost.
        _view_box(Vector3(0.0, 0.105, -0.25), Vector3(0.055, 0.025, 0.34), grip_material)
        _view_box(Vector3(0.0, 0.155, -0.36), Vector3(0.045, 0.07, 0.045), accent_material)
        _view_box(Vector3(0.0, 0.145, -0.06), Vector3(0.055, 0.05, 0.045), accent_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.54), 0.032, 0.28, body_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.69), 0.038, 0.035, grip_material)
    else:
        _view_box(Vector3(0.0, 0.09, 0.11), Vector3(0.09, 0.07, 0.08), accent_material)
        _view_box(Vector3(0.0, 0.105, -0.16), Vector3(0.045, 0.022, 0.18), grip_material)
        _view_box(Vector3(0.0, 0.15, -0.23), Vector3(0.035, 0.055, 0.035), accent_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.32), 0.024, 0.20, body_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.425), 0.03, 0.03, grip_material)

    # Fine receiver details improve the first-person silhouette while keeping
    # the weapon fully procedural, low-poly, and free of extra physics.
    var detail_material := StandardMaterial3D.new()
    detail_material.albedo_color = Color(0.32, 0.39, 0.43) if is_rifle else Color(0.40, 0.43, 0.45)
    detail_material.metallic = 0.72
    detail_material.roughness = 0.34
    var dark_detail_material := StandardMaterial3D.new()
    dark_detail_material.albedo_color = Color(0.025, 0.032, 0.038)
    dark_detail_material.metallic = 0.18
    dark_detail_material.roughness = 0.86

    if is_rifle:
        # Top rail notches and side receiver plates.
        for rail_index in range(6):
            _view_box(
                Vector3(0.0, 0.121, -0.34 + float(rail_index) * 0.075),
                Vector3(0.072, 0.012, 0.025),
                detail_material
            )
        _view_box(Vector3(0.084, 0.025, -0.10), Vector3(0.012, 0.075, 0.16), detail_material)
        _view_box(Vector3(-0.084, 0.025, -0.10), Vector3(0.012, 0.075, 0.16), detail_material)
        _view_box(Vector3(0.086, 0.045, -0.22), Vector3(0.012, 0.035, 0.09), dark_detail_material)
        # Magazine ribs and compact fasteners add a manufactured finish.
        for rib_index in range(4):
            _view_box(
                Vector3(0.0, -0.13 + float(rib_index) * 0.035, 0.126),
                Vector3(0.092, 0.012, 0.012),
                detail_material
            )
        for side in [-1.0, 1.0]:
            _view_cylinder(Vector3(side * 0.087, 0.025, -0.04), 0.012, 0.018, detail_material)
            _view_cylinder(Vector3(side * 0.087, 0.025, -0.16), 0.012, 0.018, detail_material)
    else:
        # Pistol slide serrations, front sight insert, and grip texture.
        for serration in range(5):
            _view_box(
                Vector3(0.0, 0.128, -0.22 + float(serration) * 0.032),
                Vector3(0.092, 0.012, 0.010),
                detail_material
            )
        _view_box(Vector3(0.0, 0.187, -0.245), Vector3(0.025, 0.018, 0.035), accent_material)
        for grip_rib in range(4):
            _view_box(
                Vector3(0.0, -0.16 + float(grip_rib) * 0.035, 0.125),
                Vector3(0.095, 0.012, 0.012),
                detail_material
            )

    # A brief emissive flash at the muzzle adds shot feedback without lights,
    # particles, physics, or per-frame allocations.
    muzzle_flash = MeshInstance3D.new()
    muzzle_flash.name = "MuzzleFlash"
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.085
    flash_mesh.height = 0.17
    muzzle_flash.mesh = flash_mesh
    muzzle_flash.position = Vector3(0.0, 0.015, -0.84 if is_rifle else -0.50)
    muzzle_flash.scale = Vector3(0.72, 1.25, 1.7)
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color = Color(1.0, 0.66, 0.16)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.32, 0.045)
    flash_material.emission_energy_multiplier = 3.0
    muzzle_flash.material_override = flash_material
    muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.visible = false
    view_weapon_root.add_child(muzzle_flash)

func _trigger_muzzle_flash() -> void:
    if muzzle_flash == null:
        return
    muzzle_flash_timer = 0.055
    view_weapon_recoil = maxf(view_weapon_recoil, 0.075)
    muzzle_flash.visible = true

func _view_cylinder(pos: Vector3, radius: float, height: float, material: StandardMaterial3D) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation_degrees.x = 90.0
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    view_weapon_root.add_child(mesh_instance)

func _view_box(pos: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    view_weapon_root.add_child(mesh_instance)
