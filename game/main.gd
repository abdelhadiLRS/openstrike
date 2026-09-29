extends Node3D

const GRAVITY := 14.0
const SENS := 0.0022
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_CAMERA_Y := 0.55
const CROUCH_CAMERA_Y := 0.30
const CAMERA_BASE_FOV := 75.0
const CAMERA_FOV_PRESETS := [75.0, 85.0, 95.0]
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
const MAX_IMPACT_MARKS := 32
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
var match_info_panel: PanelContainer
var compact_hud_mode := false
var cinematic_hud_mode := false
var round_banner_label: Label
var visual_notice_label: Label
var visual_notice_timer := 0.0
var round_banner_timer := 0.0
var round_banner_signature := ""
var health_bar: ProgressBar
var ammo_bar: ProgressBar
var health_hud_label: Label
var ammo_hud_label: Label
var elimination_feedback_label: Label
var elimination_feedback_panel: PanelContainer
var elimination_feedback_timer := 0.0
var kill_feed_label: Label
var kill_feed_entries: Array[Dictionary] = []
const KILL_FEED_MAX_ENTRIES := 4
const KILL_FEED_ENTRY_DURATION := 4.5
var crosshair_root: Control
var crosshair_segments: Array[ColorRect] = []
var crosshair_spread_current := 5.0
var crosshair_target_refresh_timer := 0.0
var crosshair_target_state := 0
var objective_compass_a: Label
var objective_compass_b: Label
var network_debug_hud: Label
var network_debug_visible := false
var tactical_minimap: Control
var tactical_minimap_visible := true
var scoreboard_panel: PanelContainer
var scoreboard_label: Label
var scoreboard_visible := false
var low_spec_mode := false
var balanced_visual_mode := false
var reduced_motion_mode := false
var visual_environment: Environment
var map_key_light: DirectionalLight3D
var view_weapon_root: Node3D
var view_weapon_base_position := Vector3(0.28, -0.24, -0.56)
var view_weapon_bob_time := 0.0
var view_weapon_look_input := Vector2.ZERO
var view_weapon_look_sway := Vector2.ZERO
var camera_bob_time := 0.0
var camera_bob_offset := Vector2.ZERO
var camera_roll_current := 0.0
var damage_camera_kick := Vector2.ZERO
var camera_fov_kick := 0.0
var aiming_down_sights := false
var aim_blend := 0.0
var camera_fov_preset_index := 0
var landing_camera_kick := 0.0
var view_weapon_recoil := 0.0
var view_weapon_shot_pitch := 0.0
var view_weapon_bolt: MeshInstance3D
var view_weapon_bolt_timer := 0.0
const VIEW_WEAPON_BOLT_DURATION := 0.11
var view_weapon_reload_timer := 0.0
var view_weapon_inspect_timer := 0.0
var view_weapon_switch_timer := 0.0
const VIEW_WEAPON_RELOAD_DURATION := 0.62
const VIEW_WEAPON_INSPECT_DURATION := 1.10
const VIEW_WEAPON_SWITCH_DURATION := 0.30
var muzzle_flash: MeshInstance3D
var muzzle_flash_timer := 0.0
var shell_casing_material: StandardMaterial3D
var shell_casings: Array[MeshInstance3D] = []
const MAX_SHELL_CASINGS := 12
var impact_marks: Array[MeshInstance3D] = []
var hit_marker: Label
var damage_flash: ColorRect
var damage_direction_indicator: Label
var damage_direction_timer := 0.0
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
var bomb_explosion_core: MeshInstance3D
var bomb_explosion_ring: MeshInstance3D
var bomb_explosion_core_material: StandardMaterial3D
var bomb_explosion_ring_material: StandardMaterial3D
var bomb_explosion_effect_timer := 0.0
const BOMB_EXPLOSION_EFFECT_DURATION := 0.85
var site_beacon_materials: Array[StandardMaterial3D] = []
var rotating_site_markers: Array[Node3D] = []
var site_marker_materials: Dictionary = {}
var ventilation_fan_rotors: Array[Node3D] = []
var ambient_dust_motes: Array[MeshInstance3D] = []
var ambient_dust_origins: Array[Vector3] = []
var ambient_dust_time := 0.0
var landing_dust_ring: MeshInstance3D
var landing_dust_material: StandardMaterial3D
var landing_dust_timer := 0.0
var player_was_airborne := false
var site_beacon_time := 0.0
var arena_status_time := 0.0
var arena_status_materials: Array[StandardMaterial3D] = []
var arena_status_base_energy: Array[float] = []
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
    var launch_args := OS.get_cmdline_user_args()
    low_spec_mode = launch_args.has("--low-spec")
    balanced_visual_mode = launch_args.has("--balanced-visual") and not low_spec_mode
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
    _create_landing_dust_effect()
    _hud()
    _create_round_banner()
    _create_visual_notice()
    _create_crosshair()
    _create_damage_direction_indicator()
    _create_objective_compass()
    _create_elimination_feedback()
    _create_kill_feed()
    _create_network_debug_hud()
    _create_tactical_minimap()
    _create_scoreboard_overlay()
    _start_round()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead:
        player.rotate_y(-event.relative.x * SENS)
        pitch = clamp(pitch - event.relative.y * SENS, -1.45, 1.45)
        pending_look_delta += event.relative
        view_weapon_look_input += event.relative
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_F3:
            network_debug_visible = not network_debug_visible
            if network_debug_hud != null:
                network_debug_hud.visible = network_debug_visible
        elif event.keycode == KEY_TAB:
            scoreboard_visible = true
            _update_scoreboard_overlay()
            if scoreboard_panel != null:
                scoreboard_panel.visible = true
        elif event.keycode == KEY_F4:
            if low_spec_mode:
                low_spec_mode = false
                balanced_visual_mode = false
            elif balanced_visual_mode:
                balanced_visual_mode = false
                low_spec_mode = true
            else:
                low_spec_mode = false
                balanced_visual_mode = true
            _apply_visual_quality_mode()
            _show_visual_notice("VISUAL QUALITY  /  " + _visual_quality_label(), Color(0.35, 0.86, 1.0))
        elif event.keycode == KEY_F5:
            reduced_motion_mode = not reduced_motion_mode
            _show_visual_notice("REDUCED MOTION  /  " + ("ON" if reduced_motion_mode else "OFF"), Color(0.72, 0.92, 1.0))
            camera_bob_offset = Vector2.ZERO
            if reduced_motion_mode:
                damage_camera_kick = Vector2.ZERO
                landing_camera_kick = 0.0
        elif event.keycode == KEY_F6:
            compact_hud_mode = not compact_hud_mode
            if is_instance_valid(match_info_panel):
                match_info_panel.visible = not compact_hud_mode
            _show_visual_notice("COMPACT HUD  /  " + ("ON" if compact_hud_mode else "OFF"), Color(0.35, 0.86, 1.0))
        elif event.keycode == KEY_F7:
            tactical_minimap_visible = not tactical_minimap_visible
            if is_instance_valid(tactical_minimap):
                tactical_minimap.visible = tactical_minimap_visible
            _show_visual_notice("TACTICAL MAP  /  " + ("ON" if tactical_minimap_visible else "OFF"), Color(0.35, 0.86, 1.0))
        elif event.keycode == KEY_F8:
            camera_fov_preset_index = (camera_fov_preset_index + 1) % CAMERA_FOV_PRESETS.size()
            var selected_fov := float(CAMERA_FOV_PRESETS[camera_fov_preset_index])
            _show_visual_notice("FIELD OF VIEW  /  %d°" % int(selected_fov), Color(0.35, 0.86, 1.0))
        elif event.keycode == KEY_F9:
            cinematic_hud_mode = not cinematic_hud_mode
            if is_instance_valid(hud_layer):
                hud_layer.visible = not cinematic_hud_mode
            if not cinematic_hud_mode:
                _show_visual_notice("CLEAN SCREEN  /  OFF", Color(0.35, 0.86, 1.0))
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
    elif event is InputEventKey and event.keycode == KEY_TAB and not event.pressed:
        scoreboard_visible = false
        if scoreboard_panel != null:
            scoreboard_panel.visible = false
    elif event is InputEventMouseButton and not dead:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            aiming_down_sights = event.pressed and view_weapon_reload_timer <= 0.0 and view_weapon_inspect_timer <= 0.0 and view_weapon_switch_timer <= 0.0
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    _update_site_beacon_pulse(delta)
    _update_arena_status_lights(delta)
    _update_rotating_site_markers(delta)
    _update_ventilation_fans(delta)
    _update_ambient_dust(delta)
    _update_landing_dust(delta)
    _update_view_weapon_motion(delta)
    _update_crosshair()
    _update_objective_compass()
    _update_elimination_feedback(delta)
    _update_kill_feed(delta)
    _update_bomb_explosion_effect(delta)
    _update_round_banner(delta)
    _update_visual_notice(delta)

func _update_view_weapon_motion(delta: float) -> void:
    if not is_instance_valid(view_weapon_root) or not is_instance_valid(player):
        return
    var local_velocity := player.global_transform.basis.inverse() * player.velocity
    local_velocity.y = 0.0
    var speed_ratio := clampf(local_velocity.length() / 5.6, 0.0, 1.0)
    view_weapon_bob_time += delta * (2.0 + speed_ratio * 7.5)
    view_weapon_recoil = move_toward(view_weapon_recoil, 0.0, delta * 1.35)
    camera_fov_kick = move_toward(camera_fov_kick, 0.0, delta * 5.0)
    landing_camera_kick = move_toward(landing_camera_kick, 0.0, delta * 3.8)
    view_weapon_shot_pitch = move_toward(view_weapon_shot_pitch, 0.0, delta * 2.2)
    view_weapon_bolt_timer = maxf(0.0, view_weapon_bolt_timer - delta)
    if is_instance_valid(view_weapon_bolt):
        var bolt_progress := 1.0 - view_weapon_bolt_timer / VIEW_WEAPON_BOLT_DURATION
        view_weapon_bolt.position.z = -0.02 + 0.055 * sin(clampf(bolt_progress, 0.0, 1.0) * PI)
    view_weapon_reload_timer = maxf(0.0, view_weapon_reload_timer - delta)
    view_weapon_inspect_timer = maxf(0.0, view_weapon_inspect_timer - delta)
    view_weapon_switch_timer = maxf(0.0, view_weapon_switch_timer - delta)
    if dead or view_weapon_reload_timer > 0.0 or view_weapon_inspect_timer > 0.0 or view_weapon_switch_timer > 0.0:
        aiming_down_sights = false
    aim_blend = move_toward(aim_blend, 1.0 if aiming_down_sights else 0.0, delta * 7.5)
    var reload_phase := 1.0 - view_weapon_reload_timer / VIEW_WEAPON_RELOAD_DURATION
    var reload_amount := sin(clampf(reload_phase, 0.0, 1.0) * PI)
    var inspect_phase := 1.0 - view_weapon_inspect_timer / VIEW_WEAPON_INSPECT_DURATION
    var switch_phase := 1.0 - view_weapon_switch_timer / VIEW_WEAPON_SWITCH_DURATION
    var switch_amount := sin(clampf(switch_phase, 0.0, 1.0) * PI)
    var inspect_amount := sin(clampf(inspect_phase, 0.0, 1.0) * PI)
    # A small second-phase twist gives the inspection gesture a deliberate
    # turn-and-return silhouette while remaining entirely viewmodel-only.
    var inspect_twist := sin(clampf(inspect_phase, 0.0, 1.0) * TAU)
    var bob_amount := 0.0 if reduced_motion_mode else speed_ratio * (0.012 if not crouched else 0.006)
    var bob_x := cos(view_weapon_bob_time * 0.5) * bob_amount * 0.65

    # Subtle camera head-bob and lateral sway make movement feel grounded.
    # The offset is cosmetic and remains local to the first-person camera.
    camera_bob_time += delta * (2.0 + speed_ratio * (7.0 if not crouched else 5.0))
    var camera_bob_strength := 0.0 if reduced_motion_mode else speed_ratio * (0.024 if not crouched else 0.010)
    var camera_target_offset := Vector2(
        -local_velocity.x * 0.0018 + sin(camera_bob_time * 0.5) * camera_bob_strength * 0.32,
        absf(sin(camera_bob_time)) * camera_bob_strength
    )
    camera_bob_offset = camera_bob_offset.lerp(camera_target_offset, minf(delta * 8.0, 1.0))
    # A very small strafe-linked camera roll adds physicality without obscuring
    # the reticle; F5 disables it together with other continuous motion.
    var target_camera_roll := 0.0 if reduced_motion_mode else clampf(-local_velocity.x * 0.0022, -0.012, 0.012)
    camera_roll_current = lerpf(camera_roll_current, target_camera_roll, minf(delta * 7.0, 1.0))
    damage_camera_kick = damage_camera_kick.lerp(Vector2.ZERO, minf(delta * 11.0, 1.0))
    if is_instance_valid(camera):
        camera.rotation.z = camera_roll_current
        camera.position.x = camera_bob_offset.x + damage_camera_kick.x
        camera.position.y = (CROUCH_CAMERA_Y if crouched else STAND_CAMERA_Y) + camera_bob_offset.y - landing_camera_kick + damage_camera_kick.y
        # A tiny speed-based FOV lift and short shot pulse add motion feedback
        # without changing aim direction, movement, or network state.
        var target_fov := float(CAMERA_FOV_PRESETS[camera_fov_preset_index]) - 11.0 * aim_blend + (0.0 if reduced_motion_mode else speed_ratio * (1.8 if not crouched else 0.6) * (1.0 - aim_blend)) + camera_fov_kick
        camera.fov = lerpf(camera.fov, target_fov, minf(delta * 8.0, 1.0))
    # The weapon lags slightly behind quick camera turns, then settles smoothly.
    # This is viewmodel-only, is disabled by reduced-motion mode, and never
    # feeds back into camera aim, hit registration, or network state.
    var look_target := Vector2.ZERO
    if not reduced_motion_mode:
        look_target = Vector2(
            clampf(-view_weapon_look_input.x * 0.00075, -0.028, 0.028),
            clampf(view_weapon_look_input.y * 0.00055, -0.020, 0.020)
        )
    view_weapon_look_sway = view_weapon_look_sway.lerp(look_target, minf(delta * 13.0, 1.0))
    view_weapon_look_input = Vector2.ZERO
    var bob_y := absf(sin(view_weapon_bob_time)) * bob_amount
    var sway_x := 0.0 if reduced_motion_mode else clampf(-local_velocity.x * 0.006, -0.035, 0.035)
    # Gentle idle breathing keeps the weapon from looking frozen while standing.
    # It is presentation-only and disabled by reduced-motion mode.
    var idle_sway_x := 0.0 if reduced_motion_mode else sin(view_weapon_bob_time * 0.62) * 0.0035
    var idle_sway_y := 0.0 if reduced_motion_mode else cos(view_weapon_bob_time * 0.62) * 0.0025
    var idle_sway_roll := 0.0 if reduced_motion_mode else sin(view_weapon_bob_time * 0.42) * 0.006
    # Crouching lowers and slightly rolls the viewmodel so the weapon posture
    # matches the camera stance; this remains presentation-only.
    var crouch_weapon_drop := 0.055 if crouched else 0.0
    var crouch_weapon_roll := 0.045 if crouched else 0.0
    var aim_offset := Vector3(-0.23, 0.13, 0.23)
    var target_position := view_weapon_base_position + aim_offset * aim_blend + Vector3(
        (sway_x + bob_x + idle_sway_x + view_weapon_look_sway.x + 0.12 * inspect_amount + 0.035 * inspect_twist) * (1.0 - aim_blend),
        (bob_y + idle_sway_y + view_weapon_look_sway.y) * (1.0 - aim_blend) - crouch_weapon_drop - 0.20 * reload_amount - 0.10 * inspect_amount - 0.035 * inspect_twist + 0.18 * switch_amount - landing_camera_kick * 0.45,
        view_weapon_recoil + 0.06 * reload_amount + 0.06 * inspect_amount + 0.08 * switch_amount
    )
    var target_rotation := Vector3(
        sin(view_weapon_bob_time) * bob_amount * 0.65 + view_weapon_shot_pitch - 0.18 * reload_amount + 0.10 * inspect_amount + 0.05 * inspect_twist + landing_camera_kick * 0.55,
        -view_weapon_look_sway.x * 0.55 + 0.38 * inspect_amount + 0.14 * inspect_twist,
        ((0.0 if reduced_motion_mode else -local_velocity.x * 0.006) + idle_sway_roll + crouch_weapon_roll) * (1.0 - aim_blend) + 0.22 * reload_amount - 0.48 * inspect_amount - 0.10 * inspect_twist + 0.22 * switch_amount
    )
    view_weapon_root.position = view_weapon_root.position.lerp(target_position, minf(delta * 10.0, 1.0))
    view_weapon_root.rotation = view_weapon_root.rotation.lerp(target_rotation, minf(delta * 9.0, 1.0))

func _physics_process(delta: float) -> void:
    if network_session != null and network_session.is_server:
        network_session.set_server_tick(combat_events.tick)
    _update_bomb_visual()
    player_snapshots.push(combat_events.tick, player.global_position, player.rotation.y, health)
    var is_network_client := network_session != null and network_session.is_online and not network_session.is_server
    if dead:
        if is_network_client:
            _update_hud()
            return
        respawn_timer = maxf(0.0, respawn_timer - delta)
        if respawn_timer <= 0.0:
            _respawn_player()
        _update_hud()
        return

    if not is_network_client:
        _update_round_state(delta)
    if is_network_client and round_state == "LIVE" and pending_prediction_replay:
        _replay_pending_prediction(delta)
    if round_state != "LIVE":
        if is_network_client and (pending_buy_weapon_id != "" or pending_switch_weapon or pending_reload):
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
    var move_speed := (3.4 if command.crouch else 5.6) if is_network_client else _current_speed()
    player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, 25.0 * delta)
    player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, 25.0 * delta)

    if command.jump and player.is_on_floor() and not crouched:
        player.velocity.y = 5.0

    var want_crouch := command.crouch
    if want_crouch != crouched:
        _set_crouch(want_crouch)

    if command.fire and not is_network_client:
        _fire()
    if command.reload and not is_network_client:
        _reload()

    var was_on_floor := player.is_on_floor()
    var landing_speed := player.velocity.y
    player.move_and_slide()
    if not was_on_floor and player.is_on_floor():
        landing_camera_kick = 0.0 if reduced_motion_mode else clampf(absf(landing_speed) * 0.025, 0.045, 0.22)
        if not reduced_motion_mode and absf(landing_speed) >= 3.2:
            _spawn_landing_dust(absf(landing_speed))
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
    var previous_objective_state := objective_state
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
    if previous_objective_state != "EXPLODED" and objective_state == "EXPLODED":
        _trigger_bomb_explosion_visual(snapshot.dropped_bomb_position if snapshot.planted_site == "" else (bomb_site_a if snapshot.planted_site == "A" else bomb_site_b))
    planted_site = snapshot.planted_site
    bomb_time_left = snapshot.bomb_time_left
    bomb_carrier_peer_id = snapshot.carrier_peer_id
    dropped_bomb_position = snapshot.dropped_bomb_position
    objective_action = snapshot.objective_action
    objective_action_peer_id = snapshot.objective_action_peer_id
    objective_action_time_left = snapshot.objective_action_time_left
    credits = clampi(snapshot.credits, 0, MAX_CREDITS)
    primary_owned = snapshot.owned_weapons.has("ar_17")
    var previous_weapon_id := str(_current_weapon().get("id", ""))
    var authoritative_index := -1
    for i in weapons.size():
        if str(weapons[i].get("id", "")) == snapshot.weapon_id:
            authoritative_index = i
            break
    if authoritative_index >= 0:
        weapon_index = authoritative_index
        ammo = snapshot.ammo
        reserve = snapshot.reserve
        if previous_weapon_id != snapshot.weapon_id:
            view_weapon_switch_timer = VIEW_WEAPON_SWITCH_DURATION
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
            _trigger_bomb_explosion_visual(bomb_site_a if planted_site == "A" else bomb_site_b)
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
    # Local weapon kick adds a readable, lightweight firing response without
    # changing the authoritative shot direction or player movement.
    view_weapon_recoil = minf(view_weapon_recoil + 0.045 + float(weapon["recoil"]) * 0.16, 0.16)
    if is_instance_valid(view_weapon_bolt):
        view_weapon_bolt_timer = VIEW_WEAPON_BOLT_DURATION
    camera_fov_kick = minf(camera_fov_kick + 0.85 + float(weapon["recoil"]) * 0.55, 2.8)
    view_weapon_shot_pitch = maxf(view_weapon_shot_pitch - 0.035 - float(weapon["recoil"]) * 0.08, -0.14)
    combat_events.advance_tick()
    combat_events.emit_shot("player", str(weapon["id"]), ammo, reserve)

    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var tracer_end: Vector3 = hit.position if not hit.is_empty() else origin + direction * 75.0
    var tracer_color := Color(0.50, 0.88, 1.0) if str(weapon["id"]) == "ar_17" else Color(1.0, 0.68, 0.28)
    # Keep hit registration camera-centered, but render the streak from the
    # actual first-person barrel so shots visually leave the weapon, not the
    # middle of the screen.
    var tracer_start := _weapon_muzzle_world_position()
    _spawn_shot_tracer(tracer_start, tracer_end, tracer_color)
    if not hit.is_empty():
        var impact_normal: Vector3 = hit.get("normal", Vector3.UP)
        _spawn_impact_spark(hit.position, impact_normal, tracer_color)
        var impact_collider = hit.get("collider")
        if impact_collider != null and not impact_collider.has_method("take_damage"):
            _spawn_impact_mark(hit.position, impact_normal)

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

func _weapon_muzzle_world_position() -> Vector3:
    if not is_instance_valid(view_weapon_root):
        return camera.global_position if is_instance_valid(camera) else Vector3.ZERO
    var is_rifle := str(_current_weapon().get("id", "")) == "ar_17"
    # Coordinates match the procedural rifle/pistol barrel tips in
    # _refresh_view_weapon(); the viewmodel is parented to the camera.
    return view_weapon_root.to_global(Vector3(0.0, 0.0, -0.82 if is_rifle else -0.50))


func _spawn_shot_tracer(start_position: Vector3, end_position: Vector3, tint: Color) -> void:
    # A layered emissive streak makes shots readable against both dark cover
    # and bright sky. The translucent outer sleeve is omitted in low-spec mode.
    # Both meshes are cosmetic and avoid particles, physics, and dynamic lights.
    var segment := end_position - start_position
    var length := segment.length()
    if length < 0.15:
        return

    var midpoint := (start_position + end_position) * 0.5
    var direction := segment / length
    if not low_spec_mode:
        var tracer_halo := MeshInstance3D.new()
        tracer_halo.name = "ShotTracerHalo"
        var halo_mesh := CylinderMesh.new()
        halo_mesh.top_radius = 0.045
        halo_mesh.bottom_radius = 0.045
        halo_mesh.height = length
        tracer_halo.mesh = halo_mesh
        tracer_halo.global_position = midpoint
        tracer_halo.quaternion = Quaternion(Vector3.UP, direction)
        var halo_material := StandardMaterial3D.new()
        halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        halo_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
        halo_material.emission_enabled = true
        halo_material.emission = tint * 0.28
        halo_material.emission_energy_multiplier = 0.7
        tracer_halo.material_override = halo_material
        tracer_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(tracer_halo)
        get_tree().create_timer(0.065).timeout.connect(tracer_halo.queue_free)

    var tracer := MeshInstance3D.new()
    tracer.name = "ShotTracer"
    var tracer_mesh := CylinderMesh.new()
    tracer_mesh.top_radius = 0.014
    tracer_mesh.bottom_radius = 0.014
    tracer_mesh.height = length
    tracer.mesh = tracer_mesh
    tracer.global_position = midpoint
    tracer.quaternion = Quaternion(Vector3.UP, direction)

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
    # Eject a tiny brass casing with restrained per-shot variation. The effect
    # is render-only and bounded so sustained fire cannot grow the scene tree.
    # Low-spec mode skips this decorative animation to reduce per-shot nodes/tweens.
    if low_spec_mode or not is_instance_valid(camera):
        return
    for index in range(shell_casings.size() - 1, -1, -1):
        if not is_instance_valid(shell_casings[index]):
            shell_casings.remove_at(index)
    while shell_casings.size() >= MAX_SHELL_CASINGS:
        var oldest := shell_casings.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()
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
    var eject_side := randf_range(0.62, 0.82)
    var start := camera.global_position + basis.x * randf_range(0.27, 0.34) - basis.y * randf_range(0.19, 0.25) - basis.z * 0.42
    casing.global_position = start
    casing.global_rotation = camera.global_rotation + Vector3(
        randf_range(0.55, 1.05),
        randf_range(-0.5, 0.65),
        randf_range(-0.85, 0.85)
    )
    add_child(casing)
    shell_casings.append(casing)

    var end_position := start + basis.x * eject_side - basis.y * randf_range(0.78, 1.02) + basis.z * randf_range(0.16, 0.38)
    var spin := Vector3(randf_range(4.2, 6.2), randf_range(2.8, 4.5), randf_range(5.8, 8.2))
    var tween := create_tween().set_parallel(true)
    tween.tween_property(casing, "global_position", end_position, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(casing, "rotation", casing.rotation + spin, 0.62)
    tween.tween_property(casing, "scale", Vector3.ZERO, 0.22).set_delay(0.40)
    tween.finished.connect(_on_shell_casing_finished.bind(casing))


func _on_shell_casing_finished(casing: MeshInstance3D) -> void:
    shell_casings.erase(casing)
    if is_instance_valid(casing):
        casing.queue_free()

func _spawn_landing_dust(impact_speed: float) -> void:
    # A brief floor ring sells a hard landing without particles, physics, or
    # lights. It is cosmetic only and is disabled by low-spec/reduced-motion.
    if low_spec_mode or reduced_motion_mode or not is_instance_valid(player):
        return
    var ring := MeshInstance3D.new()
    ring.name = "LandingDustRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.34
    ring_mesh.outer_radius = 0.43
    ring_mesh.ring_segments = 12
    ring_mesh.radial_segments = 4
    ring.mesh = ring_mesh
    ring.global_position = Vector3(player.global_position.x, 0.035, player.global_position.z)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var ring_material := StandardMaterial3D.new()
    ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_material.albedo_color = Color(0.60, 0.72, 0.78, 0.30)
    ring.material_override = ring_material
    add_child(ring)
    var spread := lerpf(1.25, 2.1, clampf((impact_speed - 3.2) / 7.0, 0.0, 1.0))
    var tween := create_tween().set_parallel(true)
    tween.tween_property(ring, "scale", Vector3(spread, 0.22, spread), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.finished.connect(ring.queue_free)


func _spawn_impact_spark(position: Vector3, surface_normal: Vector3, tint: Color) -> void:
    # A compact star-shaped flash makes impacts readable against dark concrete.
    # It uses four tiny unshaded meshes and a short lifetime—no particles,
    # dynamic lights, collision, or persistent nodes. Low-spec mode keeps the
    # tracer and impact mark but skips these extra transient meshes.
    if low_spec_mode:
        return
    var normal := surface_normal.normalized()
    if normal.length_squared() < 0.01:
        normal = Vector3.UP

    var spark := Node3D.new()
    spark.name = "ImpactSpark"
    spark.global_position = position + normal * 0.035
    spark.quaternion = Quaternion(Vector3.UP, normal)
    add_child(spark)

    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = tint
    material.emission_enabled = true
    material.emission = tint
    material.emission_energy_multiplier = 2.8

    var core := MeshInstance3D.new()
    core.name = "Core"
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.045
    core_mesh.height = 0.09
    core.mesh = core_mesh
    core.material_override = material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spark.add_child(core)

    for ray_index in range(3):
        var ray := MeshInstance3D.new()
        ray.name = "Ray%d" % ray_index
        var ray_mesh := BoxMesh.new()
        ray_mesh.size = Vector3(0.24 if ray_index == 0 else 0.16, 0.018, 0.018)
        ray.mesh = ray_mesh
        ray.rotation.z = deg_to_rad(float(ray_index) * 60.0)
        ray.material_override = material
        ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spark.add_child(ray)

    spark.scale = Vector3(0.72, 0.72, 0.72)
    var tween := create_tween()
    tween.tween_property(spark, "scale", Vector3(1.35, 1.35, 1.35), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.finished.connect(spark.queue_free)


func _spawn_impact_mark(position: Vector3, surface_normal: Vector3) -> void:
    # Keep only a small number of short-lived marks so sustained fire cannot
    # grow the scene tree without bound on low-memory machines.
    while impact_marks.size() >= MAX_IMPACT_MARKS:
        var oldest := impact_marks.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

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
    # Small per-impact variation prevents repeated shots from stamping a
    # perfectly identical pattern. Roll is around the surface normal, so the
    # mark remains flush against floors, walls, and angled cover.
    var impact_roll := randf_range(-PI, PI)
    mark.quaternion = Quaternion(Vector3.UP, normal) * Quaternion(Vector3.UP, impact_roll)
    var impact_scale := randf_range(0.84, 1.18)
    mark.scale = Vector3.ONE * impact_scale
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.025, 0.032, 0.04, 0.78)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 1.0
    mark.material_override = material

    # A thin outer scorch rim adds a little material definition to the impact
    # without textures, particles, extra lights, or collision.
    var rim := MeshInstance3D.new()
    rim.name = "ImpactRim"
    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = 0.078
    rim_mesh.outer_radius = 0.098
    rim_mesh.rings = 8
    rim_mesh.ring_segments = 5
    rim.mesh = rim_mesh
    var rim_material := StandardMaterial3D.new()
    rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rim_material.albedo_color = Color(0.11, 0.075, 0.045, 0.72)
    rim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rim_material.roughness = 1.0
    rim.material_override = rim_material
    rim.position.y = 0.004
    rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mark.add_child(rim)

    # A tiny, short-lived three-ray spark burst makes hard-surface impacts
    # easier to read. It is unshaded, shadow-free, and contains no particles,
    # lights, collision, or persistent nodes.
    var spark_material := StandardMaterial3D.new()
    spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_material.albedo_color = Color(1.0, 0.66, 0.24, 0.92)
    spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    spark_material.emission_enabled = true
    spark_material.emission = Color(0.95, 0.28, 0.055)
    spark_material.emission_energy_multiplier = 1.2
    for spark_index in range(3):
        var spark := MeshInstance3D.new()
        spark.name = "ImpactSpark_%d" % spark_index
        var spark_mesh := BoxMesh.new()
        spark_mesh.size = Vector3(0.095, 0.008, 0.018)
        spark.mesh = spark_mesh
        spark.position = Vector3(0.075, 0.006, 0.0)
        spark.rotation.y = deg_to_rad(float(spark_index) * 60.0)
        spark.material_override = spark_material
        spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mark.add_child(spark)

    add_child(mark)
    impact_marks.append(mark)

    var spark_tween := create_tween()
    spark_tween.tween_property(spark_material, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    var tween := create_tween()
    tween.tween_property(material, "albedo_color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(rim_material, "albedo_color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.finished.connect(_on_impact_mark_fade_finished.bind(mark))


func _on_impact_mark_fade_finished(mark: MeshInstance3D) -> void:
    impact_marks.erase(mark)
    if is_instance_valid(mark):
        mark.queue_free()


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
    if view_weapon_reload_timer > 0.0:
        return
    view_weapon_switch_timer = VIEW_WEAPON_SWITCH_DURATION
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

func _create_round_banner() -> void:
    # Short phase cards make round transitions legible without covering the reticle.
    round_banner_label = Label.new()
    round_banner_label.name = "RoundTransitionBanner"
    round_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    round_banner_label.position = Vector2(-270.0, 86.0)
    round_banner_label.size = Vector2(540.0, 92.0)
    round_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    round_banner_label.add_theme_font_size_override("font_size", 29)
    round_banner_label.add_theme_color_override("font_color", Color(0.78, 0.95, 1.0, 1.0))
    round_banner_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    round_banner_label.add_theme_constant_override("outline_size", 6)
    round_banner_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
    round_banner_label.add_theme_constant_override("shadow_offset_x", 2)
    round_banner_label.add_theme_constant_override("shadow_offset_y", 3)
    round_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    round_banner_label.modulate.a = 0.0
    hud_layer.add_child(round_banner_label)


func _create_visual_notice() -> void:
    # Brief feedback confirms graphics/accessibility toggles without interrupting play.
    visual_notice_label = Label.new()
    visual_notice_label.name = "VisualSettingsNotice"
    visual_notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    visual_notice_label.position = Vector2(-240.0, 178.0)
    visual_notice_label.size = Vector2(480.0, 44.0)
    visual_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    visual_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    visual_notice_label.add_theme_font_size_override("font_size", 18)
    visual_notice_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
    visual_notice_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    visual_notice_label.add_theme_constant_override("outline_size", 5)
    visual_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual_notice_label.modulate.a = 0.0
    hud_layer.add_child(visual_notice_label)


func _show_visual_notice(message: String, tint: Color) -> void:
    if not is_instance_valid(visual_notice_label):
        return
    visual_notice_label.text = message
    visual_notice_label.add_theme_color_override("font_color", tint)
    visual_notice_timer = 1.65
    visual_notice_label.scale = Vector2.ONE * 0.96


func _update_visual_notice(delta: float) -> void:
    if not is_instance_valid(visual_notice_label):
        return
    visual_notice_timer = maxf(0.0, visual_notice_timer - delta)
    var fade_in := clampf((1.65 - visual_notice_timer) / 0.12, 0.0, 1.0)
    var fade_out := clampf(visual_notice_timer / 0.38, 0.0, 1.0)
    visual_notice_label.modulate.a = minf(fade_in, fade_out)
    visual_notice_label.scale = Vector2.ONE * (0.96 + 0.04 * fade_in)


func _refresh_round_banner() -> void:
    if not is_instance_valid(round_banner_label):
        return
    var signature := "%d:%s:%s" % [round_number, round_state, str(round_won)]
    if signature == round_banner_signature:
        return
    round_banner_signature = signature
    round_banner_timer = 2.4
    round_banner_label.scale = Vector2.ONE
    round_banner_label.pivot_offset = round_banner_label.size * 0.5
    match round_state:
        "BUY":
            round_banner_label.text = "ROUND %02d  /  BUY PHASE" % round_number
            round_banner_label.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0, 1.0))
        "LIVE":
            round_banner_label.text = "ROUND %02d  /  LIVE" % round_number
            round_banner_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
        "POST":
            round_banner_label.text = "ROUND %02d  /  %s" % [round_number, "VICTORY" if round_won else "DEFEAT"]
            round_banner_label.add_theme_color_override("font_color", Color(0.38, 0.96, 0.66, 1.0) if round_won else Color(1.0, 0.40, 0.28, 1.0))


func _update_round_banner(delta: float) -> void:
    if not is_instance_valid(round_banner_label):
        return
    _refresh_round_banner()
    round_banner_timer = maxf(0.0, round_banner_timer - delta)
    var fade_in := clampf((2.4 - round_banner_timer) / 0.22, 0.0, 1.0)
    var fade_out := clampf(round_banner_timer / 0.55, 0.0, 1.0)
    round_banner_label.modulate.a = minf(fade_in, fade_out)
    var scale_value := 0.94 + 0.06 * fade_in
    round_banner_label.scale = Vector2.ONE * scale_value


func _hud() -> void:
    # A lightweight HUD card keeps match information readable over bright
    # surfaces while leaving most of the view unobstructed.
    hud_layer = CanvasLayer.new()
    hud_layer.name = "OpenStrikeHUD"
    hud_layer.layer = 10

    match_info_panel = PanelContainer.new()
    var panel := match_info_panel
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
    _create_combat_status_hud()

func _create_combat_status_hud() -> void:
    # Compact bottom-corner status bars keep health and ammunition readable.
    health_hud_label = Label.new()
    health_hud_label.name = "HealthStatusLabel"
    health_hud_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    health_hud_label.position = Vector2(20.0, -94.0)
    health_hud_label.size = Vector2(250.0, 26.0)
    health_hud_label.add_theme_font_size_override("font_size", 16)
    health_hud_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.98, 1.0))
    health_hud_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.95))
    health_hud_label.add_theme_constant_override("outline_size", 3)
    health_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(health_hud_label)
    health_bar = _make_status_bar("HealthStatusBar", Vector2(20.0, -66.0), Vector2(250.0, 15.0), Color(0.18, 0.82, 0.56, 0.98))

    ammo_hud_label = Label.new()
    ammo_hud_label.name = "AmmoStatusLabel"
    ammo_hud_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    ammo_hud_label.position = Vector2(-276.0, -94.0)
    ammo_hud_label.size = Vector2(256.0, 26.0)
    ammo_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ammo_hud_label.add_theme_font_size_override("font_size", 16)
    ammo_hud_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.69, 1.0))
    ammo_hud_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.95))
    ammo_hud_label.add_theme_constant_override("outline_size", 3)
    ammo_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(ammo_hud_label)
    ammo_bar = _make_status_bar("AmmoStatusBar", Vector2(-276.0, -66.0), Vector2(256.0, 15.0), Color(0.96, 0.62, 0.20, 0.98), true)

func _make_status_bar(bar_name: String, offset: Vector2, bar_size: Vector2, fill_color: Color, right_anchored: bool = false) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.name = bar_name
    bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if right_anchored else Control.PRESET_BOTTOM_LEFT)
    bar.position = offset
    bar.size = bar_size
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.015, 0.025, 0.04, 0.88)
    background.border_color = Color(0.30, 0.42, 0.50, 0.95)
    background.set_border_width_all(1)
    background.set_corner_radius_all(3)
    bar.add_theme_stylebox_override("background", background)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(3)
    bar.add_theme_stylebox_override("fill", fill)
    hud_layer.add_child(bar)
    return bar

func _create_damage_direction_indicator() -> void:
    # A brief screen-space arrow points toward the attacker without changing
    # aim, camera rotation, hit registration, or network state.
    damage_direction_indicator = Label.new()
    damage_direction_indicator.name = "DamageDirectionIndicator"
    damage_direction_indicator.text = "▲"
    damage_direction_indicator.set_anchors_preset(Control.PRESET_CENTER)
    damage_direction_indicator.position = Vector2(-18.0, -118.0)
    damage_direction_indicator.size = Vector2(36.0, 36.0)
    damage_direction_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    damage_direction_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    damage_direction_indicator.add_theme_font_size_override("font_size", 30)
    damage_direction_indicator.add_theme_color_override("font_color", Color(1.0, 0.22, 0.14, 0.96))
    damage_direction_indicator.add_theme_color_override("font_outline_color", Color(0.025, 0.015, 0.015, 0.95))
    damage_direction_indicator.add_theme_constant_override("outline_size", 4)
    damage_direction_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
    damage_direction_indicator.visible = false
    hud_layer.add_child(damage_direction_indicator)


func _show_damage_direction(source_position: Vector3) -> void:
    if damage_direction_indicator == null or not is_finite(source_position.x) or not is_finite(source_position.y) or not is_finite(source_position.z):
        return
    var direction := source_position - player.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.001:
        return
    var local_direction := player.global_transform.basis.inverse() * direction.normalized()
    var angle := atan2(local_direction.x, -local_direction.z)
    damage_direction_indicator.position = Vector2(sin(angle) * 112.0 - 18.0, -cos(angle) * 112.0 - 18.0)
    damage_direction_indicator.rotation = angle
    damage_direction_timer = 0.65
    damage_direction_indicator.visible = true
    damage_direction_indicator.modulate.a = 1.0


func _create_objective_compass() -> void:
    # Compact top-center site bearings help players orient toward both
    # objectives without adding world geometry or changing match rules.
    objective_compass_a = Label.new()
    objective_compass_a.name = "ObjectiveCompassA"
    objective_compass_a.size = Vector2(150.0, 34.0)
    objective_compass_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_compass_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    objective_compass_a.add_theme_font_size_override("font_size", 17)
    objective_compass_a.add_theme_color_override("font_color", Color(0.38, 0.91, 1.0, 0.98))
    objective_compass_a.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    objective_compass_a.add_theme_constant_override("outline_size", 4)
    objective_compass_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(objective_compass_a)

    objective_compass_b = Label.new()
    objective_compass_b.name = "ObjectiveCompassB"
    objective_compass_b.size = Vector2(150.0, 34.0)
    objective_compass_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_compass_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    objective_compass_b.add_theme_font_size_override("font_size", 17)
    objective_compass_b.add_theme_color_override("font_color", Color(1.0, 0.70, 0.28, 0.98))
    objective_compass_b.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    objective_compass_b.add_theme_constant_override("outline_size", 4)
    objective_compass_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(objective_compass_b)
    _update_objective_compass()

func _update_objective_compass() -> void:
    if not is_instance_valid(objective_compass_a) or not is_instance_valid(objective_compass_b):
        return
    if not is_instance_valid(player) or not is_instance_valid(camera) or dead:
        objective_compass_a.visible = false
        objective_compass_b.visible = false
        return

    var viewport_size := get_viewport().get_visible_rect().size
    var aspect := maxf(0.1, viewport_size.x / maxf(1.0, viewport_size.y))
    var horizontal_fov := 2.0 * atan(tan(deg_to_rad(camera.fov) * 0.5) * aspect)
    var half_fov := maxf(0.1, horizontal_fov * 0.5)
    var center_x := viewport_size.x * 0.5

    var update_site := func(label: Label, site_position: Vector3, site_name: String) -> void:
        var offset := site_position - player.global_position
        var distance := offset.length()
        var bearing := atan2(-offset.x, -offset.z)
        var relative_bearing := wrapf(bearing - player.rotation.y, -PI, PI)
        if absf(relative_bearing) > half_fov + 0.08:
            label.visible = false
            return
        var screen_x := center_x + (relative_bearing / half_fov) * (viewport_size.x * 0.5)
        label.position = Vector2(
            clampf(screen_x - label.size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - label.size.x - 8.0)),
            76.0
        )
        label.text = "%s  •  %dm" % [site_name, roundi(distance)]
        label.visible = true

    update_site.call(objective_compass_a, bomb_site_a, "A  /  ALPHA")
    update_site.call(objective_compass_b, bomb_site_b, "B  /  BRAVO")


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

    _refresh_crosshair_target()
    var reticle_color := Color(0.98, 0.30, 0.24, 0.98) if crosshair_target_state == 1 else (Color(0.24, 0.82, 1.0, 0.98) if crosshair_target_state == 2 else Color(0.78, 0.96, 1.0, 0.96))
    var reticle_alpha := 0.30 if aim_blend > 0.65 else 0.98
    for segment_index in range(4):
        crosshair_segments[segment_index].color = Color(reticle_color.r, reticle_color.g, reticle_color.b, reticle_alpha)
    var viewport_size := get_viewport().get_visible_rect().size
    var center := viewport_size * 0.5
    var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length() if is_instance_valid(player) else 0.0
    var target_spread := 5.0 + clampf(horizontal_speed * 1.25, 0.0, 10.0) + clampf(recoil_kick * 16.0, 0.0, 8.0)
    if is_instance_valid(player) and not player.is_on_floor():
        target_spread += 5.0
    if crouched:
        target_spread *= 0.72
    # ADS tightens the cosmetic reticle and dims the outer bars as the camera
    # settles into the sight picture. This is presentation-only; hit registration
    # and weapon spread remain governed by the existing combat rules.
    target_spread *= lerpf(1.0, 0.34, aim_blend)
    # Smooth bloom recovery avoids a jittery reticle while retaining immediate
    # feedback for movement, jumps, and recoil.
    crosshair_spread_current = lerpf(crosshair_spread_current, target_spread, minf(get_process_delta_time() * 14.0, 1.0))
    var spread := crosshair_spread_current
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
    crosshair_segments[4].color = Color(1.0, 0.68, 0.20, 1.0) if crosshair_target_state == 0 else reticle_color


func _refresh_crosshair_target() -> void:
    crosshair_target_refresh_timer -= get_process_delta_time()
    if crosshair_target_refresh_timer > 0.0:
        return
    crosshair_target_refresh_timer = 0.08
    crosshair_target_state = 0
    if not is_instance_valid(camera) or not is_instance_valid(player):
        return
    var ray_end := camera.global_position - camera.global_transform.basis.z * 100.0
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, ray_end)
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var target = hit.get("collider")
    if target == null or not target.has_method("take_damage"):
        return
    var target_team := str(target.get("team"))
    if target_team.is_empty():
        return
    crosshair_target_state = 2 if target_team == player_team else 1


func _create_elimination_feedback() -> void:
    # A compact, layered kill-confirmation card reinforces successful
    # eliminations while remaining a lightweight screen-space UI element.
    elimination_feedback_panel = PanelContainer.new()
    elimination_feedback_panel.name = "EliminationFeedbackPanel"
    elimination_feedback_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    elimination_feedback_panel.position = Vector2(-220.0, 92.0)
    elimination_feedback_panel.size = Vector2(440.0, 58.0)
    elimination_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.018, 0.045, 0.052, 0.92)
    panel_style.border_color = Color(0.95, 0.65, 0.20, 0.96)
    panel_style.set_border_width_all(1)
    panel_style.border_width_left = 4
    panel_style.set_corner_radius_all(7)
    panel_style.content_margin_left = 16.0
    panel_style.content_margin_right = 16.0
    panel_style.content_margin_top = 5.0
    panel_style.content_margin_bottom = 5.0
    elimination_feedback_panel.add_theme_stylebox_override("panel", panel_style)

    elimination_feedback_label = Label.new()
    elimination_feedback_label.name = "EliminationFeedback"
    elimination_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    elimination_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    elimination_feedback_label.text = "ELIMINATION  +$%d" % KILL_REWARD
    elimination_feedback_label.add_theme_font_size_override("font_size", 23)
    elimination_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
    elimination_feedback_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.98))
    elimination_feedback_label.add_theme_constant_override("outline_size", 3)
    elimination_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    elimination_feedback_panel.add_child(elimination_feedback_label)
    elimination_feedback_panel.visible = false
    hud_layer.add_child(elimination_feedback_panel)

func _show_elimination_feedback() -> void:
    elimination_feedback_timer = 1.15
    if not is_instance_valid(elimination_feedback_panel) or elimination_feedback_label == null:
        return
    elimination_feedback_label.text = "ELIMINATION  +$%d" % KILL_REWARD
    elimination_feedback_panel.visible = true
    elimination_feedback_panel.modulate = Color.WHITE
    elimination_feedback_panel.scale = Vector2.ONE

func _update_elimination_feedback(delta: float) -> void:
    if not is_instance_valid(elimination_feedback_panel):
        return
    elimination_feedback_timer = maxf(0.0, elimination_feedback_timer - delta)
    if elimination_feedback_timer <= 0.0:
        elimination_feedback_panel.visible = false
        return
    var progress := clampf(elimination_feedback_timer / 1.15, 0.0, 1.0)
    elimination_feedback_panel.modulate.a = minf(1.0, progress * 2.8)
    elimination_feedback_panel.scale = Vector2.ONE * (1.0 + 0.10 * (1.0 - progress))

func _create_kill_feed() -> void:
    # A compact recent-elimination feed adds match context without covering the
    # center reticle. It is screen-space only and does not affect combat state.
    kill_feed_label = Label.new()
    kill_feed_label.name = "RecentEliminationFeed"
    kill_feed_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    kill_feed_label.position = Vector2(-380.0, 205.0)
    kill_feed_label.size = Vector2(350.0, 132.0)
    kill_feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    kill_feed_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    kill_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    kill_feed_label.add_theme_font_size_override("font_size", 15)
    kill_feed_label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.98, 1.0))
    kill_feed_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.98))
    kill_feed_label.add_theme_constant_override("outline_size", 4)
    kill_feed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    kill_feed_label.text = ""
    kill_feed_label.visible = false
    hud_layer.add_child(kill_feed_label)


func _combatant_display_name(combatant_id: String) -> String:
    if combatant_id == "player":
        return "YOU"
    var peer_id := combatant_id.to_int()
    if peer_id > 0 and str(peer_id) == combatant_id:
        return "PLAYER %02d" % peer_id
    for index in bots.size():
        var bot = bots[index]
        if is_instance_valid(bot) and str(bot.get_instance_id()) == combatant_id:
            return "RED BOT %02d" % (int(bot.get("combat_slot")) + 1)
    return "UNIT"


func _push_kill_feed(event: OpenStrikeCombatEvent) -> void:
    if event == null or event.type != OpenStrikeCombatEvent.Type.ELIMINATION:
        return
    var weapon_label := event.weapon_id.to_upper().replace("_", "-")
    if weapon_label.is_empty():
        weapon_label = "UNKNOWN"
    var line := "%s   ›   %s   ·   %s" % [
        _combatant_display_name(event.shooter_id),
        _combatant_display_name(event.target_id),
        weapon_label
    ]
    kill_feed_entries.append({"text": line, "time_left": KILL_FEED_ENTRY_DURATION})
    while kill_feed_entries.size() > KILL_FEED_MAX_ENTRIES:
        kill_feed_entries.pop_front()
    _refresh_kill_feed()


func _update_kill_feed(delta: float) -> void:
    if kill_feed_entries.is_empty():
        if is_instance_valid(kill_feed_label):
            kill_feed_label.visible = false
        return
    for index in range(kill_feed_entries.size() - 1, -1, -1):
        var entry: Dictionary = kill_feed_entries[index]
        entry["time_left"] = maxf(0.0, float(entry.get("time_left", 0.0)) - delta)
        if float(entry["time_left"]) <= 0.0:
            kill_feed_entries.remove_at(index)
    _refresh_kill_feed()


func _refresh_kill_feed() -> void:
    if not is_instance_valid(kill_feed_label):
        return
    if kill_feed_entries.is_empty():
        kill_feed_label.text = ""
        kill_feed_label.visible = false
        return
    var lines: Array[String] = []
    var newest_time := 0.0
    for index in range(kill_feed_entries.size() - 1, -1, -1):
        var entry: Dictionary = kill_feed_entries[index]
        lines.append(str(entry.get("text", "")))
        if index == kill_feed_entries.size() - 1:
            newest_time = float(entry.get("time_left", 0.0))
    kill_feed_label.text = "\n".join(lines)
    kill_feed_label.modulate.a = clampf(newest_time / 0.55, 0.0, 1.0) if newest_time < 0.55 else 1.0
    kill_feed_label.visible = true


func _create_tactical_minimap() -> void:
    var minimap_script = load("res://ui/tactical_minimap.gd")
    if minimap_script == null:
        push_warning("OpenStrike: tactical minimap script could not be loaded.")
        return
    tactical_minimap = minimap_script.new()
    tactical_minimap.setup(self)
    tactical_minimap.visible = tactical_minimap_visible
    hud_layer.add_child(tactical_minimap)


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

func _create_scoreboard_overlay() -> void:
    scoreboard_panel = PanelContainer.new()
    scoreboard_panel.name = "ScoreboardOverlay"
    scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
    scoreboard_panel.position = Vector2(-260.0, -190.0)
    scoreboard_panel.custom_minimum_size = Vector2(520.0, 380.0)
    scoreboard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scoreboard_panel.visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.012, 0.025, 0.04, 0.94)
    style.border_color = Color(0.10, 0.66, 0.78, 0.98)
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.content_margin_left = 20.0
    style.content_margin_right = 20.0
    style.content_margin_top = 18.0
    style.content_margin_bottom = 18.0
    scoreboard_panel.add_theme_stylebox_override("panel", style)
    scoreboard_label = Label.new()
    scoreboard_label.name = "ScoreboardContent"
    scoreboard_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scoreboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    scoreboard_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    scoreboard_label.add_theme_font_size_override("font_size", 18)
    scoreboard_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.98))
    scoreboard_panel.add_child(scoreboard_label)
    if hud_layer != null:
        hud_layer.add_child(scoreboard_panel)
    else:
        add_child(scoreboard_panel)
    _update_scoreboard_overlay()


func _update_scoreboard_overlay() -> void:
    if scoreboard_label == null:
        return
    var phase := round_state
    if round_state == "POST":
        phase = "VICTORY" if round_won else "DEFEAT"
    var lines := PackedStringArray()
    lines.append("OPENSTRIKE  /  MATCH SCOREBOARD")
    lines.append("BLUE  %02d   —   %02d  RED" % [team_score, enemy_score])
    lines.append("ROUND %02d   |   %s   |   %03d SEC" % [round_number, phase, ceili(round_state_time_left if round_state != "LIVE" else round_time_left)])
    lines.append("")
    lines.append("BLUE TEAM")
    lines.append("YOU  ·  %s  ·  HP %03d  ·  $%04d" % ["DOWN" if dead else "ALIVE", maxi(0, health), credits])
    var remote_count := 0
    if network_session != null:
        for peer_value in network_session.network_players.keys():
            var remote = network_session.network_players.get(peer_value)
            if not is_instance_valid(remote):
                continue
            remote_count += 1
            lines.append("PLAYER #%d  ·  %s  ·  HP %03d" % [int(peer_value), "DOWN" if bool(remote.get("dead")) else "ALIVE", maxi(0, int(remote.get("health")))])
    if remote_count == 0:
        lines.append("NO CONNECTED BLUE PLAYERS")
    lines.append("")
    lines.append("RED TEAM  ·  %02d BOTS" % bots.size())
    for bot in bots:
        if not is_instance_valid(bot):
            continue
        var bot_id := int(bot.get("network_bot_id"))
        if bot_id <= 0:
            bot_id = int(bot.get("combat_slot")) + 1
        lines.append("BOT #%02d  ·  %s  ·  HP %03d" % [bot_id, "DOWN" if bool(bot.get("dead")) else "ALIVE", maxi(0, int(bot.get("health")))])
    lines.append("")
    lines.append("HOLD TAB TO CLOSE")
    scoreboard_label.text = "\n".join(lines)


func _show_hit_feedback() -> void:
    hit_feedback_timer = 0.14
    if hit_marker != null:
        hit_marker.visible = true
        hit_marker.modulate.a = 1.0

func _update_combat_feedback() -> void:
    if damage_direction_indicator != null:
        damage_direction_timer = maxf(0.0, damage_direction_timer - get_process_delta_time())
        damage_direction_indicator.visible = damage_direction_timer > 0.0 and not dead
        damage_direction_indicator.modulate.a = clampf(damage_direction_timer / 0.65, 0.0, 1.0)
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
    _refresh_round_banner()
    _update_scoreboard_overlay()
    var weapon := _current_weapon()
    var state := "CROUCH" if crouched else "STAND"
    var phase := round_state
    if round_state == "POST":
        phase = "WON" if round_won else "LOST"
    var phase_time := round_state_time_left if round_state != "LIVE" else round_time_left

    if dead:
        hud.text = "ROUND %02d  %s\nYOU ARE DOWN — RESPAWNING %0.1fs" % [round_number, phase, respawn_timer]
        _update_combat_status_hud(weapon)
        return

    var buy_line := ""
    if round_state == "BUY":
        buy_line = "BUY: [1] %s $%d   [2] %s $%d" % [
            weapons[0]["name"], weapons[0]["cost"], weapons[1]["name"], weapons[1]["cost"]
        ]

    hud.text = "ROUND %02d  %s  %03d\nTEAM %s  %02d - %02d    CREDITS $%04d\n%s\n%s\n%s    %s    AMMO %02d / %02d\nHP %03d    ENEMIES %02d\nWASD move   CTRL crouch   SPACE jump   LMB fire   RMB aim   R reload   E switch   T inspect   F objective\nESC mouse   F3 netgraph   F4 visuals %s   F5 motion %s   F6 compact HUD %s   F7 map %s   F8 FOV %d°" % [
        round_number, phase, ceili(phase_time), player_team, team_score, enemy_score,
        credits, buy_line, _objective_label(), weapon["name"], state, ammo, reserve, health, enemies_alive,
        _visual_quality_label(),
        "REDUCED" if reduced_motion_mode else "FULL",
        "ON" if compact_hud_mode else "OFF",
        "ON" if tactical_minimap_visible else "OFF",
        int(CAMERA_FOV_PRESETS[camera_fov_preset_index])
    ]
    _update_network_debug_hud()
    _update_objective_progress_ui()
    _update_combat_status_hud(weapon)

func _update_combat_status_hud(weapon: Dictionary) -> void:
    if health_bar != null:
        health_bar.value = clampf(float(health), 0.0, float(MAX_HEALTH))
        var health_fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
        if health_fill != null:
            health_fill.bg_color = Color(0.92, 0.20, 0.16, 0.98) if health <= 30 else (Color(0.96, 0.60, 0.18, 0.98) if health <= 55 else Color(0.18, 0.82, 0.56, 0.98))
    if health_hud_label != null:
        health_hud_label.text = "HEALTH  %03d / %03d" % [maxi(0, health), MAX_HEALTH]
    var magazine_size := maxi(1, int(weapon.get("mag", 1)))
    if ammo_bar != null:
        ammo_bar.value = clampf(float(ammo) / float(magazine_size) * 100.0, 0.0, 100.0)
        var ammo_fill := ammo_bar.get_theme_stylebox("fill") as StyleBoxFlat
        if ammo_fill != null:
            ammo_fill.bg_color = Color(0.92, 0.20, 0.16, 0.98) if ammo <= 4 else Color(0.96, 0.62, 0.20, 0.98)
    if ammo_hud_label != null:
        var low_ammo := ammo <= 4
        if ammo <= 0:
            ammo_hud_label.text = "EMPTY  /  RELOAD  ·  %02d RESERVE" % reserve
        elif low_ammo:
            ammo_hud_label.text = "LOW AMMO  %02d / %02d" % [ammo, reserve]
        else:
            ammo_hud_label.text = "AMMO  %02d / %02d" % [ammo, reserve]
        ammo_hud_label.add_theme_color_override(
            "font_color",
            Color(1.0, 0.28, 0.20, 1.0) if low_ammo else Color(0.96, 0.89, 0.69, 1.0)
        )

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
    var fps := Engine.get_frames_per_second()
    var frame_ms := 1000.0 / maxf(1.0, float(fps))
    network_debug_hud.text = "NETGRAPH [%s]  FPS %d  FRAME %.1f ms\nTX %d  RX %d  ACK %d  PENDING %d\nREJECT %d  RXDROP %d  ROSTER %d  GAPS %d  CORR %d  TICK %d%s" % [
        mode,
        fps,
        frame_ms,
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
    _push_kill_feed(event)

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

func _apply_damage(amount: int, source_position: Vector3 = Vector3.INF) -> void:
    if dead or round_state != "LIVE":
        return
    damage_feedback_timer = 0.18
    _show_damage_direction(source_position)
    # A brief, damped camera impulse reinforces incoming damage without changing aim input or movement state.
    damage_camera_kick = Vector2.ZERO if reduced_motion_mode else Vector2(randf_range(-0.028, 0.028), -0.055)
    health = maxi(0, health - amount)
    if health == 0:
        _kill_player()

func _kill_player() -> void:
    damage_direction_timer = 0.0
    if damage_direction_indicator != null:
        damage_direction_indicator.visible = false
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
    _create_perimeter_supply_crates()
    _create_ambient_dust()
    _create_mid_lane_markings()
    _create_mid_lane_signage()
    _create_floor_panel_seams()
    _create_floor_safety_markings()
    _create_spawn_wayfinding()
    _create_wall_ribs()
    _create_wall_light_fixtures()
    _create_overhead_gantry()
    _create_ceiling_light_banks()
    _create_ceiling_cable_runs()
    _create_distant_skyline()
    _create_wall_signage()
    _create_tactical_wall_displays()
    _create_wall_ventilation_details()
    _create_floor_grates()
    _create_floor_service_panels()
    _create_cover_visual_details()
    _create_cover_corner_reinforcement()
    _create_site_perimeter_lights()
    _create_site_floor_stencils()
    var objective_floor_stencils := Node3D.new()
    objective_floor_stencils.name = "ObjectiveFloorStencils"
    objective_floor_stencils.set_script(load("res://visuals/objective_floor_stencils.gd"))
    add_child(objective_floor_stencils)
    _create_site_beacons()
    _create_rotating_site_markers()
    _spawn_bots()
    _objective_site(BOMB_SITE_A, "A")
    _objective_site(BOMB_SITE_B, "B")
    _create_bomb_visual()
    _create_bomb_explosion_visual()



func _create_mid_lane_signage() -> void:
    # A suspended two-sided MID sign gives the central lane a clear landmark.
    # It is composed of a few shadow-free meshes and labels; no lights,
    # collision, navigation, or gameplay state are added.
    var housing := StandardMaterial3D.new()
    housing.albedo_color = Color(0.025, 0.045, 0.060)
    housing.metallic = 0.42
    housing.roughness = 0.62

    var cyan_trim := StandardMaterial3D.new()
    cyan_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cyan_trim.albedo_color = Color(0.10, 0.72, 0.92)
    cyan_trim.emission_enabled = true
    cyan_trim.emission = Color(0.025, 0.34, 0.58)
    cyan_trim.emission_energy_multiplier = 1.05

    var amber_trim := StandardMaterial3D.new()
    amber_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_trim.albedo_color = Color(0.96, 0.57, 0.18)
    amber_trim.emission_enabled = true
    amber_trim.emission = Color(0.42, 0.15, 0.025)
    amber_trim.emission_energy_multiplier = 0.75

    _visual_box(Vector3(0.0, 3.02, 0.0), Vector3(7.6, 0.78, 0.18), housing)
    _visual_box(Vector3(0.0, 3.43, 0.0), Vector3(7.7, 0.045, 0.22), cyan_trim)
    _visual_box(Vector3(0.0, 2.61, 0.0), Vector3(7.7, 0.045, 0.22), amber_trim)
    for side in [-1.0, 1.0]:
        _visual_box(Vector3(side * 3.72, 3.02, 0.0), Vector3(0.12, 0.80, 0.24), cyan_trim)
        _visual_box(Vector3(side * 3.42, 3.52, 0.0), Vector3(0.10, 0.42, 0.10), housing)

    for side in [-1.0, 1.0]:
        var label := Label3D.new()
        label.name = "MidControlSignFront" if side > 0.0 else "MidControlSignBack"
        label.text = "MID  /  CONTROL"
        label.position = Vector3(0.0, 3.02, side * 0.105)
        label.rotation.y = 0.0 if side > 0.0 else PI
        label.font_size = 54
        label.pixel_size = 0.010
        label.modulate = Color(0.56, 0.88, 0.96)
        label.outline_size = 8
        label.outline_modulate = Color(0.01, 0.025, 0.035, 0.98)
        label.shaded = false
        add_child(label)


func _create_ceiling_light_banks() -> void:
    # Ceiling-level industrial light banks add a stronger arena silhouette.
    # They are emissive, shadow-free meshes only: no dynamic lights, collision,
    # particles, or navigation changes, keeping the effect friendly to iGPUs.
    var housing_material := StandardMaterial3D.new()
    housing_material.albedo_color = Color(0.045, 0.065, 0.085)
    housing_material.metallic = 0.38
    housing_material.roughness = 0.66

    var diffuser_material := StandardMaterial3D.new()
    diffuser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    diffuser_material.albedo_color = Color(0.34, 0.76, 0.88)
    diffuser_material.emission_enabled = true
    diffuser_material.emission = Color(0.12, 0.48, 0.72)
    diffuser_material.emission_energy_multiplier = 1.15

    var amber_material := StandardMaterial3D.new()
    amber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_material.albedo_color = Color(0.95, 0.58, 0.20)
    amber_material.emission_enabled = true
    amber_material.emission = Color(0.62, 0.22, 0.045)
    amber_material.emission_energy_multiplier = 0.75

    for index in range(5):
        var z := -12.0 + float(index) * 6.0
        _visual_box(Vector3(0.0, 3.72, z), Vector3(12.8, 0.16, 0.72), housing_material)
        _visual_box(Vector3(0.0, 3.625, z), Vector3(11.6, 0.035, 0.24), diffuser_material)
        # Small amber end caps distinguish the fixture banks without adding
        # extra lights or competing with the A/B objective colors.
        for side in [-1.0, 1.0]:
            _visual_box(Vector3(side * 6.15, 3.625, z), Vector3(0.32, 0.04, 0.30), amber_material)


func _create_ceiling_cable_runs() -> void:
    # Paired overhead service conduits add layered industrial depth above the
    # combat lanes. They are render-only meshes with shadows disabled.
    var conduit_material := StandardMaterial3D.new()
    conduit_material.albedo_color = Color(0.065, 0.085, 0.105)
    conduit_material.metallic = 0.48
    conduit_material.roughness = 0.58

    var clamp_material := StandardMaterial3D.new()
    clamp_material.albedo_color = Color(0.20, 0.25, 0.28)
    clamp_material.metallic = 0.52
    clamp_material.roughness = 0.62

    var status_material := StandardMaterial3D.new()
    status_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    status_material.albedo_color = Color(0.10, 0.48, 0.62)
    status_material.emission_enabled = true
    status_material.emission = Color(0.025, 0.20, 0.32)
    status_material.emission_energy_multiplier = 0.75

    for x in [-9.4, 9.4]:
        _visual_box(Vector3(x, 3.42, 0.0), Vector3(0.18, 0.18, 30.0), conduit_material)
        _visual_box(Vector3(x, 3.53, 0.0), Vector3(0.055, 0.025, 29.6), status_material)
        for z in range(-12, 13, 4):
            _visual_box(Vector3(x, 3.28, float(z)), Vector3(0.34, 0.10, 0.18), clamp_material)
            _visual_box(Vector3(x, 3.18, float(z)), Vector3(0.08, 0.10, 0.10), clamp_material)

    # Small junction housings mark the service runs where they approach the
    # central lighting banks, adding depth without extra lights or collision.
    for x in [-9.4, 9.4]:
        for z in [-6.0, 6.0]:
            _visual_box(Vector3(x, 3.28, z), Vector3(0.42, 0.22, 0.62), clamp_material)
            _visual_box(Vector3(x, 3.405, z), Vector3(0.22, 0.025, 0.30), status_material)


func _create_floor_panel_seams() -> void:
    # Fine concrete expansion joints break up the broad gray floor plane.
    # These are shallow render-only strips: no collider, shadow, or navigation cost.
    var seam_material := StandardMaterial3D.new()
    seam_material.albedo_color = Color(0.105, 0.125, 0.145)
    seam_material.roughness = 0.98
    seam_material.metallic = 0.02

    # Main slab joints, with short cross-joints to suggest modular floor panels.
    for z in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
        _visual_box(Vector3(0.0, 0.009, z), Vector3(31.5, 0.012, 0.035), seam_material)
    for x in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
        _visual_box(Vector3(x, 0.009, 0.0), Vector3(0.035, 0.012, 31.5), seam_material)

    # Small inset service strips near the perimeter add scale and direction cues.
    var service_material := StandardMaterial3D.new()
    service_material.albedo_color = Color(0.19, 0.23, 0.26)
    service_material.roughness = 0.86
    for z in [-15.8, 15.8]:
        _visual_box(Vector3(0.0, 0.012, z), Vector3(27.0, 0.018, 0.12), service_material)
    for x in [-15.8, 15.8]:
        _visual_box(Vector3(x, 0.012, 0.0), Vector3(0.12, 0.018, 27.0), service_material)

func _create_floor_safety_markings() -> void:
    # High-contrast, low-profile hazard paint adds scale and industrial identity
    # near the arena perimeter. These are visual-only strips: no collision,
    # shadow casting, lighting, or navigation changes.
    var hazard_material := StandardMaterial3D.new()
    hazard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    hazard_material.albedo_color = Color(0.88, 0.52, 0.16, 0.88)
    hazard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hazard_material.roughness = 0.95

    var dark_material := StandardMaterial3D.new()
    dark_material.albedo_color = Color(0.055, 0.065, 0.075)
    dark_material.roughness = 0.98

    # Short paired warning bands frame the two ends of the central lane.
    for z in [-14.4, 14.4]:
        for index in range(9):
            var x := -2.4 + float(index) * 0.6
            var stripe := _visual_box(
                Vector3(x, 0.022, z),
                Vector3(0.28, 0.014, 0.72),
                hazard_material
            )
            stripe.rotation.y = -0.30 if z < 0.0 else 0.30
        _visual_box(Vector3(0.0, 0.019, z + (0.52 if z < 0.0 else -0.52)), Vector3(6.0, 0.012, 0.06), dark_material)

    # Small corner ticks help players read the playable boundary in motion.
    for side in [-1.0, 1.0]:
        for z in [-10.0, 10.0]:
            _visual_box(Vector3(side * 15.1, 0.02, z), Vector3(0.10, 0.014, 2.2), hazard_material)


func _create_mid_lane_markings() -> void:
    # A restrained floor-stencil treatment gives the central combat lane a
    # distinct visual identity. These pieces are render-only and stay flush
    # with the floor so they do not affect movement, collision, or navigation.
    var stencil_material := StandardMaterial3D.new()
    stencil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    stencil_material.albedo_color = Color(0.22, 0.48, 0.58, 0.82)
    stencil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    stencil_material.roughness = 0.92

    var amber_material := StandardMaterial3D.new()
    amber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_material.albedo_color = Color(0.92, 0.56, 0.20, 0.88)
    amber_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    amber_material.roughness = 0.9

    # Broken centerline and paired lane ticks improve spatial orientation
    # without creating a bright, distracting stripe through the whole arena.
    for z in [-3.0, 3.0]:
        _visual_box(Vector3(0.0, 0.018, z), Vector3(0.10, 0.018, 1.45), stencil_material)
    for side in [-1.0, 1.0]:
        for z in [-4.0, 0.0, 4.0]:
            _visual_box(Vector3(side * 6.8, 0.018, z), Vector3(0.62, 0.018, 0.10), amber_material)
        # Three short chevrons point toward the central engagement lane.
        for offset in [-0.48, 0.0, 0.48]:
            var mark := _visual_box(Vector3(side * 8.0, 0.018, offset), Vector3(0.62, 0.018, 0.075), stencil_material)
            mark.rotation.y = PI / 4.0 if side < 0.0 else -PI / 4.0

    var sector_label := Label3D.new()
    sector_label.name = "MidControlFloorStencil"
    sector_label.text = "MID  /  CONTROL"
    sector_label.position = Vector3(0.0, 0.035, 0.0)
    sector_label.rotation_degrees.x = -90.0
    sector_label.font_size = 44
    sector_label.pixel_size = 0.009
    sector_label.modulate = Color(0.36, 0.62, 0.70, 0.72)
    sector_label.outline_size = 5
    sector_label.outline_modulate = Color(0.025, 0.04, 0.05, 0.72)
    sector_label.shaded = false
    add_child(sector_label)

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

    # Repeating floor chevrons make the first route into the arena obvious.
    # These are thin, shadowless visual meshes and do not affect collision.
    for lane_x in [-1.8, 0.0, 1.8]:
        for lane_index in range(3):
            var blue_z := 11.8 - float(lane_index) * 1.55
            var red_z := -11.8 + float(lane_index) * 1.55
            for side in [-1.0, 1.0]:
                var blue_arm := _visual_box(
                    Vector3(lane_x + side * 0.22, 0.026, blue_z),
                    Vector3(0.82, 0.025, 0.075),
                    blue_trim
                )
                blue_arm.rotation.y = side * deg_to_rad(38.0)
                var red_arm := _visual_box(
                    Vector3(lane_x + side * 0.22, 0.026, red_z),
                    Vector3(0.82, 0.025, 0.075),
                    red_trim
                )
                red_arm.rotation.y = -side * deg_to_rad(38.0)

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

func _create_distant_skyline() -> void:
    # Distant industrial silhouettes rise above the arena walls to frame the
    # skyline. They are deliberately outside the playable area and use only
    # shadowless render meshes: no collision, navigation, or combat changes.
    var tower_material := StandardMaterial3D.new()
    tower_material.albedo_color = Color(0.035, 0.052, 0.075)
    tower_material.roughness = 0.92
    var tower_alt_material := StandardMaterial3D.new()
    tower_alt_material.albedo_color = Color(0.065, 0.082, 0.105)
    tower_alt_material.roughness = 0.88
    var window_material := StandardMaterial3D.new()
    window_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    window_material.albedo_color = Color(0.10, 0.36, 0.48)
    window_material.emission_enabled = true
    window_material.emission = Color(0.035, 0.18, 0.28)
    window_material.emission_energy_multiplier = 0.65

    var silhouettes := [
        {"p": Vector3(-15.0, 6.4, -23.0), "s": Vector3(4.0, 5.2, 2.4)},
        {"p": Vector3(-7.0, 8.0, -24.0), "s": Vector3(3.0, 8.4, 2.8)},
        {"p": Vector3(1.0, 6.8, -23.5), "s": Vector3(5.0, 6.0, 2.5)},
        {"p": Vector3(11.0, 9.0, -24.0), "s": Vector3(4.2, 10.4, 3.0)},
        {"p": Vector3(20.5, 6.5, -15.0), "s": Vector3(2.5, 5.8, 4.5)},
        {"p": Vector3(23.0, 8.0, -5.0), "s": Vector3(3.0, 8.8, 3.5)},
        {"p": Vector3(23.0, 6.8, 7.0), "s": Vector3(3.5, 6.4, 4.0)},
        {"p": Vector3(17.0, 7.2, 23.0), "s": Vector3(4.5, 6.8, 2.5)},
        {"p": Vector3(7.0, 9.0, 24.0), "s": Vector3(3.4, 10.0, 3.0)},
        {"p": Vector3(-4.0, 6.6, 23.5), "s": Vector3(5.0, 6.0, 2.6)},
        {"p": Vector3(-14.0, 8.2, 23.0), "s": Vector3(4.0, 8.4, 3.0)},
        {"p": Vector3(-23.0, 7.6, 12.0), "s": Vector3(3.0, 8.0, 4.0)},
        {"p": Vector3(-23.0, 6.2, 0.0), "s": Vector3(3.0, 5.2, 3.5)},
        {"p": Vector3(-22.0, 8.4, -12.0), "s": Vector3(4.0, 9.0, 4.0)}
    ]
    for index in silhouettes.size():
        var data: Dictionary = silhouettes[index]
        var position: Vector3 = data["p"]
        var size: Vector3 = data["s"]
        var material: StandardMaterial3D = tower_material if index % 2 == 0 else tower_alt_material
        _visual_box(position, size, material)
        # A narrow rooftop cap creates a readable stepped skyline at low cost.
        _visual_box(
            position + Vector3(0.0, size.y * 0.5 + 0.08, 0.0),
            Vector3(size.x * 0.72, 0.16, size.z * 0.72),
            tower_alt_material
        )
        if index % 2 == 0:
            # Tiny vertical service-light strips add scale without adding
            # dynamic lights or brightening the combat lanes.
            _visual_box(
                position + Vector3(0.0, 0.0, -size.z * 0.5 - 0.025),
                Vector3(0.10, minf(size.y * 0.55, 3.0), 0.035),
                window_material
            )

func _create_wall_light_fixtures() -> void:
    # Static wall-mounted light housings add visual depth and warm/cool contrast.
    # The fixtures are render-only: no extra lights, collision, or navigation cost.
    var housing_material := StandardMaterial3D.new()
    housing_material.albedo_color = Color(0.035, 0.052, 0.068)
    housing_material.metallic = 0.48
    housing_material.roughness = 0.56

    var cyan_lens := StandardMaterial3D.new()
    cyan_lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cyan_lens.albedo_color = Color(0.08, 0.62, 0.86)
    cyan_lens.emission_enabled = true
    cyan_lens.emission = Color(0.025, 0.32, 0.58)
    cyan_lens.emission_energy_multiplier = 1.2

    var amber_lens := StandardMaterial3D.new()
    amber_lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_lens.albedo_color = Color(0.98, 0.56, 0.18)
    amber_lens.emission_enabled = true
    amber_lens.emission = Color(0.62, 0.22, 0.035)
    amber_lens.emission_energy_multiplier = 1.0

    arena_status_materials = [cyan_lens, amber_lens]
    arena_status_base_energy = [cyan_lens.emission_energy_multiplier, amber_lens.emission_energy_multiplier]

    # Alternating fixture colors reinforce the industrial arena's sector language.
    for index in range(5):
        var coordinate := float(-12 + index * 6)
        var lens_material: StandardMaterial3D = cyan_lens if index % 2 == 0 else amber_lens
        for side in [-1.0, 1.0]:
            var z := side * 17.25
            _visual_box(Vector3(coordinate, 3.25, z), Vector3(1.65, 0.30, 0.28), housing_material)
            _visual_box(Vector3(coordinate, 3.25, z - side * 0.16), Vector3(1.28, 0.075, 0.035), lens_material)
        for side in [-1.0, 1.0]:
            var x := side * 17.25
            _visual_box(Vector3(x, 3.25, coordinate), Vector3(0.28, 0.30, 1.65), housing_material)
            _visual_box(Vector3(x - side * 0.16, 3.25, coordinate), Vector3(0.035, 0.075, 1.28), lens_material)

func _update_arena_status_lights(delta: float) -> void:
    # A restrained emissive breathing cycle gives static wall fixtures a little
    # life without adding real lights, shadows, particles, or physics work.
    if low_spec_mode or arena_status_materials.is_empty():
        return
    arena_status_time = fmod(arena_status_time + delta, TAU)
    for index in range(arena_status_materials.size()):
        var material := arena_status_materials[index]
        if not is_instance_valid(material):
            continue
        var pulse := 0.92 + (sin(arena_status_time * 0.72 + float(index) * PI) + 1.0) * 0.04
        material.emission_energy_multiplier = arena_status_base_energy[index] * pulse


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

func _create_tactical_wall_displays() -> void:
    # Wall-mounted operations displays give the arena a more deliberate
    # industrial identity and reinforce the two-site layout. They are purely
    # decorative meshes/labels: no collision, navigation, lights, or gameplay.
    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.075, 0.105, 0.13)
    frame_material.metallic = 0.62
    frame_material.roughness = 0.48

    var screen_material := StandardMaterial3D.new()
    screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    screen_material.albedo_color = Color(0.015, 0.045, 0.065)
    screen_material.emission_enabled = true
    screen_material.emission = Color(0.015, 0.085, 0.12)
    screen_material.emission_energy_multiplier = 0.55

    var cyan_material := StandardMaterial3D.new()
    cyan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cyan_material.albedo_color = Color(0.08, 0.72, 0.92)
    cyan_material.emission_enabled = true
    cyan_material.emission = Color(0.025, 0.38, 0.62)
    cyan_material.emission_energy_multiplier = 0.9

    var amber_material := StandardMaterial3D.new()
    amber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    amber_material.albedo_color = Color(0.98, 0.58, 0.20)
    amber_material.emission_enabled = true
    amber_material.emission = Color(0.55, 0.20, 0.035)
    amber_material.emission_energy_multiplier = 0.75

    for side in [-1.0, 1.0]:
        var center := Vector3(side * 17.34, 2.28, 0.0)
        var inward := Vector3(-side * 0.085, 0.0, 0.0)
        _visual_box(center, Vector3(0.16, 1.42, 2.85), frame_material)
        _visual_box(center + inward, Vector3(0.055, 1.22, 2.63), screen_material)
        _visual_box(center + inward + Vector3(0.0, 0.56, 0.0), Vector3(0.035, 0.045, 2.45), cyan_material)
        _visual_box(center + inward + Vector3(0.0, -0.50, 0.0), Vector3(0.035, 0.035, 2.45), amber_material)
        for index in range(5):
            var bar_height := 0.10 + float((index * 3 + int(side + 1.0)) % 4) * 0.055
            _visual_box(
                center + inward + Vector3(0.0, -0.28 + bar_height * 0.5, -0.82 + float(index) * 0.40),
                Vector3(0.035, bar_height, 0.13),
                cyan_material if index % 2 == 0 else amber_material
            )

        var label := Label3D.new()
        label.name = "OperationsDisplay_" + ("West" if side < 0.0 else "East")
        label.text = "OPENSTRIKE  /  OPS\nSITE A   •   MID   •   SITE B"
        label.position = center + inward + Vector3(-side * 0.035, 0.16, 0.0)
        label.rotation.y = PI * 0.5 if side < 0.0 else -PI * 0.5
        label.font_size = 24
        label.pixel_size = 0.008
        label.modulate = Color(0.62, 0.88, 0.96, 0.95)
        label.outline_size = 5
        label.outline_modulate = Color(0.005, 0.015, 0.025, 0.98)
        label.shaded = false
        add_child(label)

func _create_wall_ventilation_details() -> void:
    # Recessed-looking vent panels and service conduits break up the long side
    # walls. Every element is render-only and has no collision or light cost.
    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.045, 0.065, 0.082)
    frame_material.metallic = 0.52
    frame_material.roughness = 0.72

    var slat_material := StandardMaterial3D.new()
    slat_material.albedo_color = Color(0.22, 0.28, 0.32)
    slat_material.metallic = 0.58
    slat_material.roughness = 0.62

    var accent_material := StandardMaterial3D.new()
    accent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    accent_material.albedo_color = Color(0.04, 0.42, 0.58)
    accent_material.emission_enabled = true
    accent_material.emission = Color(0.02, 0.20, 0.32)
    accent_material.emission_energy_multiplier = 0.75

    for side in [-1.0, 1.0]:
        for lane_z in [-11.0, -5.0, 5.0, 11.0]:
            var center := Vector3(side * 17.38, 2.35, lane_z)
            var rotation := PI * 0.5 if side < 0.0 else -PI * 0.5
            var frame := _visual_box(center, Vector3(2.65, 1.18, 0.12), frame_material)
            frame.rotation.y = rotation
            var inner := _visual_box(center + Vector3(-side * 0.075, 0.0, 0.0), Vector3(2.42, 0.96, 0.045), frame_material)
            inner.rotation.y = rotation
            for slat_index in range(7):
                var local_y := -0.34 + float(slat_index) * 0.11
                var slat := _visual_box(
                    center + Vector3(-side * 0.11, local_y, 0.0),
                    Vector3(2.20, 0.045, 0.055),
                    slat_material
                )
                slat.rotation.y = rotation
            var status_strip := _visual_box(
                center + Vector3(-side * 0.12, 0.48, 0.0),
                Vector3(2.34, 0.045, 0.06),
                accent_material
            )
            status_strip.rotation.y = rotation

    # A pair of narrow service conduits runs along each wall near the ceiling.
    var conduit_material := StandardMaterial3D.new()
    conduit_material.albedo_color = Color(0.10, 0.14, 0.17)
    conduit_material.metallic = 0.42
    conduit_material.roughness = 0.78
    for side in [-1.0, 1.0]:
        _visual_box(Vector3(side * 17.25, 3.48, 0.0), Vector3(0.12, 0.14, 29.0), conduit_material)
        for lane_z in [-14.0, -7.0, 0.0, 7.0, 14.0]:
            _visual_box(Vector3(side * 17.16, 3.48, lane_z), Vector3(0.22, 0.20, 0.16), accent_material)

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

func _create_floor_service_panels() -> void:
    # Thin floor-panel seams add a manufactured concrete finish along the
    # outer lanes. These meshes are decorative only and cast no shadows.
    var seam_material := StandardMaterial3D.new()
    seam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    seam_material.albedo_color = Color(0.035, 0.055, 0.072, 0.72)
    seam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var accent_material := StandardMaterial3D.new()
    accent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    accent_material.albedo_color = Color(0.50, 0.29, 0.10, 0.72)
    accent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    for side in [-1.0, 1.0]:
        for lane_z in [-11.0, 11.0]:
            var center := Vector3(side * 12.0, 0.009, lane_z)
            var width := 4.2
            var depth := 4.2
            # Four low-profile seams outline each maintenance plate.
            _visual_box(center + Vector3(0.0, 0.0, -depth * 0.5), Vector3(width, 0.012, 0.025), seam_material)
            _visual_box(center + Vector3(0.0, 0.0, depth * 0.5), Vector3(width, 0.012, 0.025), seam_material)
            _visual_box(center + Vector3(-width * 0.5, 0.0, 0.0), Vector3(0.025, 0.012, depth), seam_material)
            _visual_box(center + Vector3(width * 0.5, 0.0, 0.0), Vector3(0.025, 0.012, depth), seam_material)
            # A short amber registration mark identifies one plate corner.
            _visual_box(
                center + Vector3(-side * (width * 0.5 - 0.36), 0.008, -depth * 0.5),
                Vector3(0.48, 0.012, 0.055),
                accent_material
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

        # Bottom hazard rail and four inset fasteners make each cover panel
        # read as a bolted modular armor plate. These are render-only meshes.
        var hazard_material := StandardMaterial3D.new()
        hazard_material.albedo_color = Color(0.78, 0.43, 0.12)
        hazard_material.metallic = 0.18
        hazard_material.roughness = 0.74
        _visual_box(
            panel_center + Vector3(0.0, -panel_height * 0.5 + 0.035, 0.032),
            Vector3(panel_width - 0.10, 0.035, 0.024),
            hazard_material
        )
        var fastener_material := StandardMaterial3D.new()
        fastener_material.albedo_color = Color(0.30, 0.37, 0.41)
        fastener_material.metallic = 0.72
        fastener_material.roughness = 0.42
        for side in [-1.0, 1.0]:
            for vertical in [-1.0, 1.0]:
                _visual_box(
                    panel_center + Vector3(
                        side * (panel_width * 0.5 - 0.12),
                        vertical * (panel_height * 0.5 - 0.10),
                        0.055
                    ),
                    Vector3(0.055, 0.055, 0.018),
                    fastener_material
                )

func _create_cover_corner_reinforcement() -> void:
    # Slim armor rails and top caps give existing cover blocks a more finished
    # modular-steel silhouette. These details are render-only and do not alter
    # the cover collision, hitboxes, bot navigation, or gameplay.
    var rail_material := StandardMaterial3D.new()
    rail_material.albedo_color = Color(0.17, 0.22, 0.26)
    rail_material.metallic = 0.58
    rail_material.roughness = 0.54

    var edge_material := StandardMaterial3D.new()
    edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_material.albedo_color = Color(0.78, 0.43, 0.15)
    edge_material.emission_enabled = true
    edge_material.emission = Color(0.22, 0.075, 0.018)
    edge_material.emission_energy_multiplier = 0.62

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
        var center: Vector3 = data["p"]
        var size: Vector3 = data["s"]
        var front_z := center.z + size.z * 0.5 + 0.065
        var rail_height := size.y * 0.72
        for side in [-1.0, 1.0]:
            _visual_box(
                Vector3(center.x + side * (size.x * 0.5 - 0.075), center.y, front_z),
                Vector3(0.075, rail_height, 0.055),
                rail_material
            )
        _visual_box(
            Vector3(center.x, center.y + size.y * 0.5 - 0.065, front_z),
            Vector3(size.x - 0.08, 0.085, 0.06),
            rail_material
        )
        _visual_box(
            Vector3(center.x, center.y - size.y * 0.5 + 0.12, front_z + 0.006),
            Vector3(size.x * 0.46, 0.035, 0.018),
            edge_material
        )


func _create_ventilation_fans() -> void:
    # Slow wall-mounted rotors add subtle industrial motion without physics,
    # collision, particles, or dynamic lights.
    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.075, 0.105, 0.13)
    frame_material.metallic = 0.55
    frame_material.roughness = 0.58
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.16, 0.23, 0.27)
    blade_material.metallic = 0.35
    blade_material.roughness = 0.64
    var hub_material := StandardMaterial3D.new()
    hub_material.albedo_color = Color(0.08, 0.42, 0.52)
    hub_material.emission_enabled = true
    hub_material.emission = Color(0.015, 0.16, 0.22)
    hub_material.emission_energy_multiplier = 0.7
    for x in [-11.5, 11.5]:
        var fan_root := Node3D.new()
        fan_root.name = "WallVentilationFan"
        fan_root.position = Vector3(x, 2.55, -17.42)
        add_child(fan_root)
        var guard := MeshInstance3D.new()
        var guard_mesh := TorusMesh.new()
        guard_mesh.inner_radius = 0.53
        guard_mesh.outer_radius = 0.59
        guard.mesh = guard_mesh
        guard.rotation.x = PI * 0.5
        guard.material_override = frame_material
        guard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fan_root.add_child(guard)
        var rotor := Node3D.new()
        rotor.name = "FanRotor"
        fan_root.add_child(rotor)
        for blade_index in range(3):
            var blade := MeshInstance3D.new()
            var blade_mesh := BoxMesh.new()
            blade_mesh.size = Vector3(0.13, 0.46, 0.055)
            blade.mesh = blade_mesh
            var angle := float(blade_index) * TAU / 3.0
            blade.position = Vector3(sin(angle) * 0.27, cos(angle) * 0.27, 0.015)
            blade.rotation.z = -angle
            blade.material_override = blade_material
            blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            rotor.add_child(blade)
        var hub := MeshInstance3D.new()
        var hub_mesh := CylinderMesh.new()
        hub_mesh.top_radius = 0.14
        hub_mesh.bottom_radius = 0.14
        hub_mesh.height = 0.12
        hub.mesh = hub_mesh
        hub.rotation.x = PI * 0.5
        hub.material_override = hub_material
        hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        rotor.add_child(hub)
        ventilation_fan_rotors.append(rotor)


func _update_ventilation_fans(delta: float) -> void:
    for rotor in ventilation_fan_rotors:
        if is_instance_valid(rotor):
            rotor.rotate_z(delta * 0.48)


func _create_ambient_dust() -> void:
    # A small set of slow, translucent motes adds depth to the arena without
    # a particle system, dynamic lights, shadows, or collision.
    var mote_mesh := SphereMesh.new()
    mote_mesh.radius = 0.018
    mote_mesh.height = 0.036
    var mote_material := StandardMaterial3D.new()
    mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mote_material.albedo_color = Color(0.48, 0.72, 0.86, 0.18)
    mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mote_material.emission_enabled = true
    mote_material.emission = Color(0.12, 0.32, 0.42)
    mote_material.emission_energy_multiplier = 0.22

    for i in range(18):
        var phase := float(i) * 2.399963
        var origin := Vector3(
            sin(phase) * 14.0,
            0.45 + float(i % 6) * 0.48,
            cos(phase) * 14.0
        )
        var mote := MeshInstance3D.new()
        mote.name = "AmbientDustMote_%02d" % i
        mote.mesh = mote_mesh
        mote.material_override = mote_material
        mote.position = origin
        mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mote.visible = not low_spec_mode
        add_child(mote)
        ambient_dust_motes.append(mote)
        ambient_dust_origins.append(origin)

func _create_landing_dust_effect() -> void:
    # One reusable ground ring gives hard landings a little visual weight.
    # It is a shadow-free mesh (not a particle system) and is disabled in low-spec mode.
    landing_dust_ring = MeshInstance3D.new()
    landing_dust_ring.name = "LandingDustRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.28
    ring_mesh.outer_radius = 0.46
    ring_mesh.rings = 8
    ring_mesh.ring_segments = 12
    landing_dust_ring.mesh = ring_mesh
    landing_dust_material = StandardMaterial3D.new()
    landing_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    landing_dust_material.albedo_color = Color(0.62, 0.72, 0.76, 0.0)
    landing_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    landing_dust_material.roughness = 1.0
    landing_dust_ring.material_override = landing_dust_material
    landing_dust_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    landing_dust_ring.visible = false
    add_child(landing_dust_ring)


func _update_landing_dust(delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(landing_dust_ring):
        return
    if not player.is_on_floor():
        player_was_airborne = true
    elif player_was_airborne:
        player_was_airborne = false
        if not low_spec_mode and not reduced_motion_mode:
            landing_dust_timer = 0.22
            landing_dust_ring.global_position = player.global_position + Vector3(0.0, 0.035, 0.0)
            landing_dust_ring.scale = Vector3.ONE * 0.22
            landing_dust_material.albedo_color.a = 0.34
            landing_dust_ring.visible = true

    if landing_dust_timer <= 0.0:
        return
    landing_dust_timer = maxf(0.0, landing_dust_timer - delta)
    var progress := 1.0 - landing_dust_timer / 0.22
    landing_dust_ring.scale = Vector3.ONE * lerpf(0.22, 1.55, progress)
    landing_dust_material.albedo_color.a = 0.34 * (1.0 - progress)
    landing_dust_ring.visible = landing_dust_timer > 0.0


func _update_ambient_dust(delta: float) -> void:
    if low_spec_mode or ambient_dust_motes.is_empty():
        return
    ambient_dust_time = fmod(ambient_dust_time + delta, TAU)
    for i in range(ambient_dust_motes.size()):
        var mote := ambient_dust_motes[i]
        if not is_instance_valid(mote):
            continue
        var origin: Vector3 = ambient_dust_origins[i]
        var phase := ambient_dust_time * 0.42 + float(i) * 1.7
        mote.position = origin + Vector3(
            sin(phase) * 0.16,
            sin(phase * 0.73) * 0.12,
            cos(phase * 0.61) * 0.14
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
    # A restrained glow pass makes emissive site beacons, warning strips, and
    # weapon flashes read as luminous accents. F4/low-spec mode disables it.
    environment.glow_enabled = not low_spec_mode
    environment.glow_intensity = 0.28
    environment.glow_strength = 0.72
    environment.glow_bloom = 0.035
    environment.glow_hdr_threshold = 1.25
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    # A light atmospheric haze softens distant wall edges while keeping the
    # compact arena readable; restrained grading separates cool concrete
    # from the cyan/amber objective accents.
    environment.fog_enabled = not low_spec_mode
    environment.fog_light_color = Color(0.16, 0.22, 0.30)
    environment.fog_density = 0.004
    environment.fog_sky_affect = 0.08
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 1.0
    environment.adjustment_contrast = 1.04
    environment.adjustment_saturation = 1.08
    environment_node.environment = environment
    visual_environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.name = "MapKeyLight"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(0.80, 0.87, 1.0)
    sun.light_energy = 1.05
    sun.shadow_enabled = not low_spec_mode
    sun.directional_shadow_max_distance = 45.0
    map_key_light = sun
    add_child(sun)
    _apply_visual_quality_mode()

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

func _apply_visual_quality_mode() -> void:
    # Runtime quality switching changes rendering only; gameplay, collision,
    # navigation, and network simulation remain intact. LOW removes fog, glow,
    # shadows, and dust; BALANCED keeps haze but skips glow and shadow maps;
    # HIGH enables the complete lightweight presentation stack.
    if is_instance_valid(visual_environment):
        visual_environment.fog_enabled = not low_spec_mode
        visual_environment.glow_enabled = not low_spec_mode and not balanced_visual_mode
        visual_environment.glow_intensity = 0.28
        visual_environment.glow_strength = 0.72
        visual_environment.glow_bloom = 0.035
        visual_environment.glow_hdr_threshold = 1.25
        visual_environment.ambient_light_energy = 0.78 if low_spec_mode else (0.69 if balanced_visual_mode else 0.62)
    if is_instance_valid(map_key_light):
        map_key_light.shadow_enabled = not low_spec_mode and not balanced_visual_mode
    for mote in ambient_dust_motes:
        if is_instance_valid(mote):
            mote.visible = not low_spec_mode


func _visual_quality_label() -> String:
    if low_spec_mode:
        return "LOW"
    if balanced_visual_mode:
        return "BALANCED"
    return "HIGH"


func _create_perimeter_supply_crates() -> void:
    # Lightweight perimeter cargo props add scale and visual storytelling.
    # They are mesh-only decorations: no collision, shadow casting, or pathing changes.
    var crate_material := StandardMaterial3D.new()
    crate_material.albedo_color = Color(0.12, 0.16, 0.18)
    crate_material.metallic = 0.28
    crate_material.roughness = 0.82

    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.26, 0.31, 0.33)
    frame_material.metallic = 0.42
    frame_material.roughness = 0.68

    var marking_material := StandardMaterial3D.new()
    marking_material.albedo_color = Color(0.86, 0.48, 0.14)
    marking_material.roughness = 0.82

    var crates := [
        {"p": Vector3(-14.2, 0.70, -12.8), "s": Vector3(1.45, 1.40, 1.25)},
        {"p": Vector3(14.2, 0.70, -12.8), "s": Vector3(1.45, 1.40, 1.25)},
        {"p": Vector3(-14.2, 0.70, 12.8), "s": Vector3(1.45, 1.40, 1.25)},
        {"p": Vector3(14.2, 0.70, 12.8), "s": Vector3(1.45, 1.40, 1.25)}
    ]
    for index in range(crates.size()):
        var spec: Dictionary = crates[index]
        var center: Vector3 = spec["p"]
        var size: Vector3 = spec["s"]
        _visual_box(center, size, crate_material)
        # Reinforced top and bottom rails make each cargo unit read as a
        # manufactured container rather than another plain cover block.
        _visual_box(center + Vector3(0.0, size.y * 0.5 - 0.10, 0.0), Vector3(size.x + 0.06, 0.12, size.z + 0.06), frame_material)
        _visual_box(center + Vector3(0.0, -size.y * 0.5 + 0.10, 0.0), Vector3(size.x + 0.06, 0.12, size.z + 0.06), frame_material)
        for side in [-1.0, 1.0]:
            _visual_box(center + Vector3(side * (size.x * 0.5 - 0.10), 0.0, -size.z * 0.5 - 0.025), Vector3(0.10, size.y * 0.72, 0.055), frame_material)
        # Small numbered stencils provide a little visual variation between props.
        var stencil := Label3D.new()
        stencil.name = "CargoStencil_" + str(index + 1)
        stencil.text = "OS-" + str(index + 1).pad_zeros(2)
        stencil.position = center + Vector3(0.0, 0.08, -size.z * 0.5 - 0.04)
        stencil.font_size = 26
        stencil.pixel_size = 0.006
        stencil.modulate = Color(0.92, 0.66, 0.30, 0.92)
        stencil.outline_size = 4
        stencil.outline_modulate = Color(0.025, 0.035, 0.04, 0.95)
        stencil.shaded = false
        add_child(stencil)
        _visual_box(center + Vector3(0.0, -0.36, -size.z * 0.5 - 0.035), Vector3(0.58, 0.045, 0.035), marking_material)


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

func _create_site_perimeter_lights() -> void:
    # Segmented, emissive floor strips make each objective zone readable from
    # its approaches. These are render-only meshes with no collision or lights.
    var site_specs := [
        {"position": BOMB_SITE_A, "color": Color(0.08, 0.72, 0.96)},
        {"position": BOMB_SITE_B, "color": Color(1.0, 0.48, 0.12)}
    ]
    for spec in site_specs:
        var center: Vector3 = spec["position"]
        var site_color: Color = spec["color"]
        var stripe_material := StandardMaterial3D.new()
        stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        stripe_material.albedo_color = site_color
        stripe_material.emission_enabled = true
        stripe_material.emission = site_color * 0.72
        stripe_material.emission_energy_multiplier = 1.15
        stripe_material.roughness = 0.9

        for segment in range(8):
            var angle := TAU * float(segment) / 8.0
            var radial := Vector3(cos(angle), 0.0, sin(angle))
            var strip := _visual_box(
                center + radial * 2.95 + Vector3(0.0, 0.035, 0.0),
                Vector3(1.05, 0.025, 0.075),
                stripe_material
            )
            strip.rotation.y = -angle

func _create_site_floor_stencils() -> void:
    # Flat site names act as close-range wayfinding when players enter either
    # objective zone. They are unlit, non-colliding labels with no gameplay use.
    var site_specs := [
        {"id": "A", "name": "ALPHA", "position": BOMB_SITE_A, "color": Color(0.28, 0.76, 0.94, 0.78)},
        {"id": "B", "name": "BRAVO", "position": BOMB_SITE_B, "color": Color(1.0, 0.62, 0.28, 0.78)}
    ]
    for spec in site_specs:
        var stencil := Label3D.new()
        stencil.name = "SiteFloorStencil_" + str(spec["id"])
        stencil.text = str(spec["id"]) + "  /  " + str(spec["name"])
        stencil.position = spec["position"] + Vector3(0.0, 0.045, 1.72)
        stencil.rotation_degrees.x = -90.0
        stencil.font_size = 58
        stencil.pixel_size = 0.010
        stencil.modulate = spec["color"]
        stencil.outline_size = 6
        stencil.outline_modulate = Color(0.015, 0.025, 0.035, 0.88)
        stencil.shaded = false
        add_child(stencil)


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
        site_beacon_materials.append(trim_material)

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

func _create_rotating_site_markers() -> void:
    # Elevated twin bars identify each site and change state when the bomb is
    # planted. Materials are shared per site; no lights, collision, or physics.
    var specs := [
        {"id": "A", "position": BOMB_SITE_A, "color": Color(1.0, 0.54, 0.16)},
        {"id": "B", "position": BOMB_SITE_B, "color": Color(0.10, 0.72, 0.98)}
    ]
    for spec in specs:
        var marker := Node3D.new()
        var site_id := str(spec["id"])
        marker.name = "RotatingSiteMarker_" + site_id
        marker.position = spec["position"] + Vector3(0.0, 3.15, 0.0)
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = spec["color"]
        material.emission_enabled = true
        material.emission = spec["color"] * 0.7
        material.emission_energy_multiplier = 1.0
        site_marker_materials[site_id] = material
        for angle in [0.0, PI * 0.5]:
            var bar := MeshInstance3D.new()
            var bar_mesh := BoxMesh.new()
            bar_mesh.size = Vector3(1.25, 0.045, 0.11)
            bar.mesh = bar_mesh
            bar.rotation.y = angle
            bar.material_override = material
            bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            marker.add_child(bar)
        add_child(marker)
        rotating_site_markers.append(marker)

func _update_rotating_site_markers(delta: float) -> void:
    var planted := objective_state == "PLANTED"
    var pulse := (sin(Time.get_ticks_msec() / 1000.0 * 5.5) + 1.0) * 0.5
    for marker in rotating_site_markers:
        if not is_instance_valid(marker):
            continue
        marker.rotation.y = fmod(marker.rotation.y + delta * (0.62 if planted else 0.38), TAU)
        var site_id := "A" if marker.name.ends_with("_A") else "B"
        var material: StandardMaterial3D = site_marker_materials.get(site_id)
        if not is_instance_valid(material):
            continue
        var base_color: Color = Color(1.0, 0.54, 0.16) if site_id == "A" else Color(0.10, 0.72, 0.98)
        if planted and site_id == planted_site:
            # The active plant site switches to urgent red and pulses faster
            # as a persistent, distant-readable objective cue.
            var urgency := clampf(1.0 - bomb_time_left / BOMB_TIME, 0.0, 1.0)
            material.albedo_color = Color(1.0, 0.16 + pulse * 0.16, 0.08)
            material.emission = Color(1.0, 0.08 + pulse * 0.12, 0.025)
            material.emission_energy_multiplier = 1.25 + urgency * 1.25 + pulse * 0.55
        elif planted:
            material.albedo_color = base_color.darkened(0.48)
            material.emission = base_color * 0.22
            material.emission_energy_multiplier = 0.45
        else:
            material.albedo_color = base_color
            material.emission = base_color * 0.7
            material.emission_energy_multiplier = 1.0

func _update_site_beacon_pulse(delta: float) -> void:
    if site_beacon_materials.is_empty():
        return
    site_beacon_time = fmod(site_beacon_time + delta, TAU)
    # A slow, low-amplitude pulse makes A/B easier to notice without lights,
    # particles, shader work, or gameplay-affecting geometry.
    var pulse := 1.45 + (sin(site_beacon_time * 1.6) + 1.0) * 0.30
    for material in site_beacon_materials:
        if is_instance_valid(material):
            material.emission_energy_multiplier = pulse

func _visual_box(pos: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh_instance)
    return mesh_instance

func _create_bomb_explosion_visual() -> void:
    # A tiny mesh-only blast cue avoids particle simulation and collision work.
    bomb_explosion_core = MeshInstance3D.new()
    bomb_explosion_core.name = "BombExplosionCore"
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.8
    core_mesh.height = 1.6
    bomb_explosion_core.mesh = core_mesh
    bomb_explosion_core_material = StandardMaterial3D.new()
    bomb_explosion_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bomb_explosion_core_material.albedo_color = Color(1.0, 0.34, 0.08, 0.72)
    bomb_explosion_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bomb_explosion_core_material.emission_enabled = true
    bomb_explosion_core_material.emission = Color(1.0, 0.16, 0.025)
    bomb_explosion_core_material.emission_energy_multiplier = 2.2
    bomb_explosion_core.material_override = bomb_explosion_core_material
    bomb_explosion_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bomb_explosion_core.visible = false
    add_child(bomb_explosion_core)

    bomb_explosion_ring = MeshInstance3D.new()
    bomb_explosion_ring.name = "BombExplosionRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.72
    ring_mesh.outer_radius = 0.88
    bomb_explosion_ring.mesh = ring_mesh
    bomb_explosion_ring.rotation.x = PI * 0.5
    bomb_explosion_ring_material = StandardMaterial3D.new()
    bomb_explosion_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bomb_explosion_ring_material.albedo_color = Color(1.0, 0.58, 0.18, 0.9)
    bomb_explosion_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bomb_explosion_ring_material.emission_enabled = true
    bomb_explosion_ring_material.emission = Color(1.0, 0.28, 0.04)
    bomb_explosion_ring_material.emission_energy_multiplier = 2.8
    bomb_explosion_ring.material_override = bomb_explosion_ring_material
    bomb_explosion_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bomb_explosion_ring.visible = false
    add_child(bomb_explosion_ring)

func _trigger_bomb_explosion_visual(position: Vector3) -> void:
    if not is_instance_valid(bomb_explosion_core) or not is_instance_valid(bomb_explosion_ring):
        return
    bomb_explosion_effect_timer = BOMB_EXPLOSION_EFFECT_DURATION
    bomb_explosion_core.global_position = position + Vector3(0.0, 0.65, 0.0)
    bomb_explosion_ring.global_position = position + Vector3(0.0, 0.12, 0.0)
    bomb_explosion_core.scale = Vector3.ONE * 0.25
    bomb_explosion_ring.scale = Vector3.ONE * 0.35
    bomb_explosion_core.visible = true
    bomb_explosion_ring.visible = true
    bomb_explosion_core_material.albedo_color.a = 0.72
    bomb_explosion_ring_material.albedo_color.a = 0.9

func _update_bomb_explosion_effect(delta: float) -> void:
    if bomb_explosion_effect_timer <= 0.0:
        return
    bomb_explosion_effect_timer = maxf(0.0, bomb_explosion_effect_timer - delta)
    var progress := 1.0 - bomb_explosion_effect_timer / BOMB_EXPLOSION_EFFECT_DURATION
    var fade := 1.0 - progress
    if is_instance_valid(bomb_explosion_core):
        bomb_explosion_core.scale = Vector3.ONE * lerpf(0.25, 4.0, progress)
        bomb_explosion_core_material.albedo_color.a = 0.72 * fade
        bomb_explosion_core_material.emission_energy_multiplier = 2.2 * fade
        bomb_explosion_core.visible = bomb_explosion_effect_timer > 0.0
    if is_instance_valid(bomb_explosion_ring):
        bomb_explosion_ring.scale = Vector3.ONE * lerpf(0.35, 5.5, progress)
        bomb_explosion_ring_material.albedo_color.a = 0.9 * fade
        bomb_explosion_ring_material.emission_energy_multiplier = 2.8 * fade
        bomb_explosion_ring.visible = bomb_explosion_effect_timer > 0.0

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
    # The arena floor uses a subtle world-space procedural concrete finish.
    # It is a single shader material with no textures, extra geometry, or lights.
    if pos == Vector3(0, -0.5, 0) and size == Vector3(36, 1, 36):
        var floor_material := ShaderMaterial.new()
        floor_material.shader = preload("res://shaders/concrete_floor.gdshader")
        mesh.material_override = floor_material
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
    var bot_role := "DEFENDER_A" if index == 0 else ("DEFENDER_B" if index == 1 else "ROAMER")
    bot.set("role", bot_role)
    bot.set("combat_slot", index)

    # Keep the visual model separate from the gameplay body so small procedural
    # locomotion motion never changes collision, navigation, or network position.
    var visual_rig := Node3D.new()
    visual_rig.name = "VisualRig"
    bot.visual_rig = visual_rig
    bot.add_child(visual_rig)

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
    left_arm.name = "LeftArm"
    var right_arm := _bot_detail(Vector3(0.18, 0.48, 0.20), Vector3(0.39, -0.13, -0.015), dark_material)
    right_arm.name = "RightArm"
    var left_leg := _bot_detail(Vector3(0.24, 0.48, 0.28), Vector3(-0.17, -0.63, 0.015), armor_material)
    left_leg.name = "LeftLeg"
    var right_leg := _bot_detail(Vector3(0.24, 0.48, 0.28), Vector3(0.17, -0.63, 0.015), armor_material)
    right_leg.name = "RightLeg"
    var backpack := _bot_detail(Vector3(0.42, 0.52, 0.20), Vector3(0.0, 0.02, 0.25), dark_material)
    var chest_rig := _bot_detail(Vector3(0.48, 0.12, 0.36), Vector3(0.0, 0.16, -0.205), armor_material)

    # Compact, render-only rifle silhouette and utility details make enemy
    # units read as armed combatants instead of capsule-shaped targets.
    var weapon_material := StandardMaterial3D.new()
    weapon_material.albedo_color = Color(0.045, 0.055, 0.065)
    weapon_material.metallic = 0.38
    weapon_material.roughness = 0.62
    # Small role-specific color accents help players distinguish enemy
    # defenders from the roamer at a glance without changing team identity.
    var role_accent := Color(0.98, 0.58, 0.18)
    if bot_role == "DEFENDER_B":
        role_accent = Color(0.92, 0.34, 0.16)
    elif bot_role == "ROAMER":
        role_accent = Color(0.72, 0.20, 0.10)
    var weapon_accent := StandardMaterial3D.new()
    weapon_accent.albedo_color = role_accent
    weapon_accent.roughness = 0.72
    weapon_accent.emission_enabled = true
    weapon_accent.emission = role_accent * 0.12
    weapon_accent.emission_energy_multiplier = 0.35
    var bot_rifle_body := _bot_detail(Vector3(0.16, 0.14, 0.68), Vector3(0.18, -0.03, -0.34), weapon_material)
    var bot_rifle_barrel := _bot_detail(Vector3(0.065, 0.065, 0.42), Vector3(0.18, 0.0, -0.84), weapon_material)
    var bot_rifle_stock := _bot_detail(Vector3(0.13, 0.13, 0.25), Vector3(0.18, -0.06, 0.12), weapon_material)
    var bot_rifle_magazine := _bot_detail(Vector3(0.095, 0.23, 0.13), Vector3(0.18, -0.21, -0.30), weapon_material)
    var bot_rifle_sight := _bot_detail(Vector3(0.075, 0.065, 0.12), Vector3(0.18, 0.105, -0.36), weapon_accent)
    var left_pouch := _bot_detail(Vector3(0.16, 0.19, 0.11), Vector3(-0.20, -0.02, -0.25), dark_material)
    var right_pouch := _bot_detail(Vector3(0.16, 0.19, 0.11), Vector3(0.20, -0.02, -0.25), dark_material)
    var shoulder_mark := _bot_detail(Vector3(0.07, 0.15, 0.18), Vector3(-0.47, 0.24, -0.02), weapon_accent)

    # Extra silhouette details: visor, segmented chest webbing, knee guards,
    # and a compact radio aerial. They remain cosmetic and share no colliders.
    var visor_material := StandardMaterial3D.new()
    visor_material.albedo_color = Color(0.025, 0.075, 0.095)
    visor_material.metallic = 0.28
    visor_material.roughness = 0.32
    var visor_glint_material := StandardMaterial3D.new()
    visor_glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    visor_glint_material.albedo_color = Color(0.10, 0.58, 0.72)
    visor_glint_material.emission_enabled = true
    visor_glint_material.emission = Color(0.025, 0.20, 0.30)
    visor_glint_material.emission_energy_multiplier = 0.55
    var visor := _bot_detail(Vector3(0.30, 0.085, 0.045), Vector3(0.0, 0.69, -0.205), visor_material)
    var visor_glint := _bot_detail(Vector3(0.22, 0.018, 0.018), Vector3(0.0, 0.70, -0.232), visor_glint_material)
    var chest_webbing := _bot_detail(Vector3(0.50, 0.055, 0.035), Vector3(0.0, 0.02, -0.225), dark_material)
    var left_knee_guard := _bot_detail(Vector3(0.22, 0.14, 0.075), Vector3(-0.17, -0.78, -0.13), dark_material)
    var right_knee_guard := _bot_detail(Vector3(0.22, 0.14, 0.075), Vector3(0.17, -0.78, -0.13), dark_material)
    var radio_aerial := _bot_detail(Vector3(0.035, 0.34, 0.035), Vector3(0.29, 0.43, 0.20), weapon_material)
    var shoulder_patch := _bot_detail(Vector3(0.10, 0.10, 0.035), Vector3(0.47, 0.25, -0.12), weapon_accent)

    visual_rig.add_child(mesh)
    visual_rig.add_child(vest)
    visual_rig.add_child(head)
    visual_rig.add_child(helmet)
    visual_rig.add_child(team_band)
    visual_rig.add_child(left_shoulder)
    visual_rig.add_child(right_shoulder)
    visual_rig.add_child(left_arm)
    visual_rig.add_child(right_arm)
    visual_rig.add_child(left_leg)
    visual_rig.add_child(right_leg)
    visual_rig.add_child(backpack)
    visual_rig.add_child(chest_rig)
    visual_rig.add_child(bot_rifle_body)
    visual_rig.add_child(bot_rifle_barrel)
    visual_rig.add_child(bot_rifle_stock)
    visual_rig.add_child(bot_rifle_magazine)
    visual_rig.add_child(bot_rifle_sight)
    visual_rig.add_child(left_pouch)
    visual_rig.add_child(right_pouch)
    visual_rig.add_child(shoulder_mark)
    visual_rig.add_child(visor)
    visual_rig.add_child(visor_glint)
    visual_rig.add_child(chest_webbing)
    visual_rig.add_child(left_knee_guard)
    visual_rig.add_child(right_knee_guard)
    visual_rig.add_child(radio_aerial)
    visual_rig.add_child(shoulder_patch)
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
    camera.fov = float(CAMERA_FOV_PRESETS[camera_fov_preset_index])
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
    view_weapon_bolt = null
    view_weapon_bolt_timer = 0.0
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
    # Materials are declared before both weapon branches so the optic and
    # later receiver details share valid, stable material references.
    var detail_material := StandardMaterial3D.new()
    detail_material.albedo_color = Color(0.32, 0.39, 0.43) if is_rifle else Color(0.40, 0.43, 0.45)
    detail_material.metallic = 0.72
    detail_material.roughness = 0.34
    var dark_detail_material := StandardMaterial3D.new()
    dark_detail_material.albedo_color = Color(0.025, 0.032, 0.038)
    dark_detail_material.metallic = 0.18
    dark_detail_material.roughness = 0.86

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

        # A compact bolt carrier reciprocates on each shot for a tactile firing
        # cue. It is part of the camera-only viewmodel and has no physics.
        view_weapon_bolt = MeshInstance3D.new()
        view_weapon_bolt.name = "RifleBoltCarrier"
        var bolt_mesh := BoxMesh.new()
        bolt_mesh.size = Vector3(0.025, 0.045, 0.12)
        view_weapon_bolt.mesh = bolt_mesh
        view_weapon_bolt.position = Vector3(0.095, 0.035, -0.02)
        view_weapon_bolt.material_override = detail_material
        view_weapon_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        view_weapon_root.add_child(view_weapon_bolt)

        # Compact reflex optic gives the rifle a more distinctive first-person
        # silhouette. Its housing and dot are visual-only and cast no shadows.
        _view_box(Vector3(0.0, 0.165, -0.075), Vector3(0.17, 0.035, 0.20), grip_material)
        _view_box(Vector3(-0.067, 0.235, -0.075), Vector3(0.025, 0.13, 0.18), body_material)
        _view_box(Vector3(0.067, 0.235, -0.075), Vector3(0.025, 0.13, 0.18), body_material)
        _view_box(Vector3(0.0, 0.292, -0.075), Vector3(0.16, 0.022, 0.18), detail_material)
        _view_box(Vector3(0.0, 0.235, 0.025), Vector3(0.12, 0.025, 0.025), detail_material)
        var optic_dot := MeshInstance3D.new()
        optic_dot.name = "ReflexOpticDot"
        var optic_dot_mesh := SphereMesh.new()
        optic_dot_mesh.radius = 0.012
        optic_dot_mesh.height = 0.024
        optic_dot.mesh = optic_dot_mesh
        optic_dot.position = Vector3(0.0, 0.235, 0.008)
        var optic_dot_material := StandardMaterial3D.new()
        optic_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        optic_dot_material.albedo_color = Color(1.0, 0.12, 0.08)
        optic_dot_material.emission_enabled = true
        optic_dot_material.emission = Color(1.0, 0.035, 0.015)
        optic_dot_material.emission_energy_multiplier = 1.25
        optic_dot.material_override = optic_dot_material
        optic_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        view_weapon_root.add_child(optic_dot)
    else:
        _view_box(Vector3(0.0, 0.09, 0.11), Vector3(0.09, 0.07, 0.08), accent_material)
        _view_box(Vector3(0.0, 0.105, -0.16), Vector3(0.045, 0.022, 0.18), grip_material)
        _view_box(Vector3(0.0, 0.15, -0.23), Vector3(0.035, 0.055, 0.035), accent_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.32), 0.024, 0.20, body_material)
        _view_cylinder(Vector3(0.0, 0.0, -0.425), 0.03, 0.03, grip_material)

    # Weapon-specific silhouette pass: stock hardware and vented handguard on
    # the rifle, plus a trigger guard and textured grip panels on the sidearm.
    # These camera-only meshes add no collision, shadows, or gameplay behavior.
    if is_rifle:
        _view_box(Vector3(0.0, -0.005, 0.405), Vector3(0.19, 0.16, 0.075), grip_material)
        _view_box(Vector3(0.0, 0.015, 0.365), Vector3(0.20, 0.035, 0.035), detail_material)
        _view_box(Vector3(0.0, 0.055, 0.19), Vector3(0.13, 0.025, 0.12), detail_material)
        for side in [-1.0, 1.0]:
            for vent_index in range(4):
                _view_box(
                    Vector3(side * 0.083, 0.012, -0.30 + float(vent_index) * 0.065),
                    Vector3(0.009, 0.026, 0.038),
                    dark_detail_material
                )
            _view_box(Vector3(side * 0.091, -0.015, 0.285), Vector3(0.018, 0.055, 0.09), detail_material)
    else:
        # A squared, open-sided trigger guard frames the trigger area without
        # obscuring the pistol's compact profile.
        _view_box(Vector3(0.0, -0.045, -0.005), Vector3(0.12, 0.018, 0.16), detail_material)
        _view_box(Vector3(-0.055, 0.005, -0.005), Vector3(0.018, 0.09, 0.16), detail_material)
        _view_box(Vector3(0.055, 0.005, -0.005), Vector3(0.018, 0.09, 0.16), detail_material)
        for side in [-1.0, 1.0]:
            _view_box(Vector3(side * 0.052, -0.13, 0.115), Vector3(0.012, 0.14, 0.12), body_material)
            _view_box(Vector3(side * 0.059, -0.15, 0.13), Vector3(0.008, 0.075, 0.075), detail_material)

    # Fine receiver details improve the first-person silhouette while keeping
    # the weapon fully procedural, low-poly, and free of extra physics.
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

    # A compact four-ray starburst makes each shot legible against bright
    # backgrounds. The rays share the parent visibility/timer and stay
    # unshaded, shadowless, and free of particle or light allocations.
    var flash_ray_material := StandardMaterial3D.new()
    flash_ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_ray_material.albedo_color = Color(1.0, 0.86, 0.48, 0.94)
    flash_ray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    flash_ray_material.emission_enabled = true
    flash_ray_material.emission = Color(1.0, 0.42, 0.08)
    flash_ray_material.emission_energy_multiplier = 2.4

    var horizontal_ray := MeshInstance3D.new()
    var horizontal_mesh := BoxMesh.new()
    horizontal_mesh.size = Vector3(0.30 if is_rifle else 0.22, 0.025, 0.025)
    horizontal_ray.mesh = horizontal_mesh
    horizontal_ray.material_override = flash_ray_material
    horizontal_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.add_child(horizontal_ray)

    var vertical_ray := MeshInstance3D.new()
    var vertical_mesh := BoxMesh.new()
    vertical_mesh.size = Vector3(0.025, 0.20 if is_rifle else 0.15, 0.025)
    vertical_ray.mesh = vertical_mesh
    vertical_ray.material_override = flash_ray_material
    vertical_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.add_child(vertical_ray)

    # Short diagonal rays create a fuller starburst while keeping the flash
    # mesh-only, unlit by the scene, and cheap on integrated graphics.
    for diagonal_sign in [-1.0, 1.0]:
        var diagonal_ray := MeshInstance3D.new()
        var diagonal_mesh := BoxMesh.new()
        diagonal_mesh.size = Vector3(0.20 if is_rifle else 0.14, 0.018, 0.022)
        diagonal_ray.mesh = diagonal_mesh
        diagonal_ray.rotation.z = deg_to_rad(32.0 * diagonal_sign)
        diagonal_ray.material_override = flash_ray_material
        diagonal_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        muzzle_flash.add_child(diagonal_ray)

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
