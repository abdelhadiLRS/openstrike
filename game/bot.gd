extends CharacterBody3D

signal eliminated(bot)

const GRAVITY := 14.0
const MOVE_SPEED := 3.4
const SPRINT_SPEED := 4.2
const DETECTION_RANGE := 26.0
const FIRE_RANGE := 22.0
const FIRE_DELAY := 0.34
const DAMAGE := 12
const OPTIMAL_RANGE := 15.0
const MIN_COMBAT_RANGE := 8.0
const ACCURACY := 0.86
const BURST_SHOTS := 3
const BURST_PAUSE := 0.65
const STRAFE_INTERVAL := 0.9
const WAYPOINT_REACHED := 1.1
const SITE_RADIUS := 2.8
const LOW_HEALTH_THRESHOLD := 40
const COVER_REACHED := 1.2
const PEEK_TIME := 1.2
const PEEK_HOLD := 0.8
const COMBAT_DECISION_INTERVAL := 0.7
const PUSH_DISTANCE := 11.0
const HOLD_DISTANCE := 20.0
const RETREAT_HEALTH_THRESHOLD := 35
const PUSH_HEALTH_THRESHOLD := 70
const RECENT_HIT_REACTION_TIME := 1.2
const COMBAT_REPOSITION_INTERVAL := 3.5
const COMBAT_REPOSITION_MIN_DISTANCE := 3.0
const ROUTE_REPLAN_INTERVAL := 1.2
const ROUTE_GOAL_CHANGE_DISTANCE := 2.5
const NETWORK_SNAPSHOT_STALE_TIME := 0.35
const NETWORK_EXTRAPOLATION_TIME := 0.12
const NETWORK_SNAP_DISTANCE := 6.0

var team := "RED"
var network_bot_id := 0
var network_target_position := Vector3.ZERO
var network_target_velocity := Vector3.ZERO
var network_target_yaw := 0.0
var network_snapshot_fresh := false
var network_snapshot_age := 0.0
var network_round_number := 0
var max_health := 100
var health := 100
var dead := false
var last_damage_source_id := ""
var fire_cooldown := 0.0
var burst_remaining := 0
var burst_pause := 0.0
var strafe_time := 0.0
var strafe_sign := 1.0
var target: Node3D
var main: Node3D
var state := "DEFEND"
var role := "DEFENDER_A"
var route := []
var route_index := 0
var current_goal := Vector3.ZERO
var last_state := "DEFEND"
var cover_index := -1
var bomb_cover_goal := Vector3.ZERO
var bomb_cover_site := ""
var bomb_cover_revision := -1
var peek_timer := 0.0
var peek_hold_timer := 0.0
var combat_intent := "HOLD"
var combat_decision_timer := 0.0
var recently_hit_timer := 0.0
var combat_reposition_timer := 0.0
var combat_slot := 0
var combat_assignment := "SUPPORT"
var combat_engagement := "READY"
var tactical_memory_position := Vector3.ZERO
var tactical_memory_timer := 0.0
var tactical_memory_revision := -1
var combat_reposition_goal := Vector3.ZERO
var retreat_cover_goal := Vector3.ZERO
var route_goal := Vector3.ZERO
var route_replan_timer := 0.0
var route_failed_goal := Vector3.ZERO
var close_retreat_route_active := false
var search_goal := Vector3.ZERO
var search_revision := -1
var squad_contact_position := Vector3.ZERO
var squad_contact_timer := 0.0
var squad_contact_revision := -1
var combat_director_phase := "IDLE"
var combat_director_command := "HOLD"
var combat_director_revision := -1
var combat_role_revision := -1
var combat_director_fire_ready := false
var squad_threat_state := "LOST"
var squad_threat_position := Vector3.ZERO
var squad_threat_revision := -1
var applied_threat_revision := -1
var flank_goal_revision := -1
var collision_shape: CollisionShape3D
var visual_rig: Node3D
var visual_left_arm: MeshInstance3D
var visual_right_arm: MeshInstance3D
var visual_left_leg: MeshInstance3D
var visual_right_leg: MeshInstance3D
var visual_motion_time := 0.0
var visual_hit_recoil := 0.0
var muzzle_flash: MeshInstance3D
var muzzle_flash_timer := 0.0
var damage_flash_ring: MeshInstance3D
var damage_flash_timer := 0.0
var damage_health_bar_root: Node3D
var damage_health_bar_fill: MeshInstance3D
var damage_health_bar_timer := 0.0
var damage_popup: Label3D
var damage_popup_tween: Tween
var damage_popup_total := 0
const DAMAGE_HEALTH_BAR_DURATION := 1.65
const MUZZLE_FLASH_DURATION := 0.055
const DAMAGE_FLASH_DURATION := 0.16

func _ready() -> void:
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
    main = get_parent()
    health = max_health
    target = main.get("player")
    visual_left_arm = visual_rig.get_node_or_null("LeftArm") as MeshInstance3D if is_instance_valid(visual_rig) else null
    visual_right_arm = visual_rig.get_node_or_null("RightArm") as MeshInstance3D if is_instance_valid(visual_rig) else null
    visual_left_leg = visual_rig.get_node_or_null("LeftLeg") as MeshInstance3D if is_instance_valid(visual_rig) else null
    visual_right_leg = visual_rig.get_node_or_null("RightLeg") as MeshInstance3D if is_instance_valid(visual_rig) else null
    _create_bot_muzzle_flash()
    _create_damage_flash_ring()
    _create_damage_health_bar()

func _create_damage_flash_ring() -> void:
    # A short red ring gives immediate hit feedback without particles or lights.
    damage_flash_ring = MeshInstance3D.new()
    damage_flash_ring.name = "BotDamageFlashRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.48
    ring_mesh.outer_radius = 0.60
    ring_mesh.ring_segments = 12
    ring_mesh.radial_segments = 4
    damage_flash_ring.mesh = ring_mesh
    damage_flash_ring.position = Vector3(0.0, 0.10, 0.0)
    var ring_material := StandardMaterial3D.new()
    ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_material.albedo_color = Color(1.0, 0.16, 0.08, 0.92)
    ring_material.emission_enabled = true
    ring_material.emission = Color(1.0, 0.055, 0.015)
    ring_material.emission_energy_multiplier = 1.4
    damage_flash_ring.material_override = ring_material
    damage_flash_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    damage_flash_ring.visible = false
    add_child(damage_flash_ring)

func _create_damage_health_bar() -> void:
    # Brief billboard health bar appears only after damage, preserving clean
    # silhouettes during idle movement while helping players read hit results.
    damage_health_bar_root = Node3D.new()
    damage_health_bar_root.name = "DamageHealthBar"
    damage_health_bar_root.position = Vector3(0.0, 1.35, 0.0)
    damage_health_bar_root.visible = false
    add_child(damage_health_bar_root)

    var background := MeshInstance3D.new()
    var background_mesh := BoxMesh.new()
    background_mesh.size = Vector3(0.92, 0.085, 0.025)
    background.mesh = background_mesh
    var background_material := StandardMaterial3D.new()
    background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    background_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    background_material.albedo_color = Color(0.025, 0.035, 0.045, 0.94)
    background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    background.material_override = background_material
    background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    damage_health_bar_root.add_child(background)

    damage_health_bar_fill = MeshInstance3D.new()
    damage_health_bar_fill.name = "HealthFill"
    var fill_mesh := BoxMesh.new()
    fill_mesh.size = Vector3(0.84, 0.045, 0.035)
    damage_health_bar_fill.mesh = fill_mesh
    damage_health_bar_fill.position = Vector3(0.0, 0.0, -0.018)
    var fill_material := StandardMaterial3D.new()
    fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    fill_material.albedo_color = Color(0.20, 0.88, 0.48, 1.0)
    damage_health_bar_fill.material_override = fill_material
    damage_health_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    damage_health_bar_root.add_child(damage_health_bar_fill)

func _spawn_damage_number(amount: int) -> void:
    # Reuse one short-lived popup per bot and stack rapid hits into a single
    # readable total instead of spawning overlapping labels during burst fire.
    if amount <= 0 or dead:
        return
    if is_instance_valid(damage_popup):
        if is_instance_valid(damage_popup_tween):
            damage_popup_tween.kill()
        damage_popup_total += amount
        damage_popup.text = "-%d" % damage_popup_total
        damage_popup.position = Vector3(randf_range(-0.18, 0.18), 1.85, randf_range(-0.12, 0.12))
        damage_popup.modulate = Color(1.0, 0.76, 0.34, 1.0)
    else:
        damage_popup_total = amount
        damage_popup = Label3D.new()
        damage_popup.name = "DamageNumber"
        damage_popup.text = "-%d" % damage_popup_total
        damage_popup.font_size = 38
        damage_popup.pixel_size = 0.008
        damage_popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        damage_popup.modulate = Color(1.0, 0.76, 0.34, 1.0)
        damage_popup.outline_size = 7
        damage_popup.outline_modulate = Color(0.055, 0.025, 0.01, 0.95)
        damage_popup.position = Vector3(randf_range(-0.18, 0.18), 1.85, randf_range(-0.12, 0.12))
        damage_popup.no_depth_test = false
        add_child(damage_popup)

    var popup := damage_popup
    damage_popup_tween = create_tween()
    damage_popup_tween.set_parallel(true)
    damage_popup_tween.tween_property(popup, "position:y", popup.position.y + 0.72, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    damage_popup_tween.tween_property(popup, "modulate:a", 0.0, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    damage_popup_tween.set_parallel(false)
    damage_popup_tween.tween_callback(_finish_damage_popup.bind(popup))


func _finish_damage_popup(popup: Label3D) -> void:
    if not is_instance_valid(popup):
        return
    popup.queue_free()
    if damage_popup == popup:
        damage_popup = null
        damage_popup_tween = null
        damage_popup_total = 0

func _show_damage_health_bar() -> void:
    if not is_instance_valid(damage_health_bar_root) or not is_instance_valid(damage_health_bar_fill):
        return
    damage_health_bar_timer = DAMAGE_HEALTH_BAR_DURATION
    damage_health_bar_root.visible = not dead
    var ratio := clampf(float(health) / maxf(1.0, float(max_health)), 0.0, 1.0)
    damage_health_bar_fill.scale.x = maxf(0.015, ratio)
    damage_health_bar_fill.position.x = -0.42 * (1.0 - ratio)
    var fill_material := damage_health_bar_fill.material_override as StandardMaterial3D
    if fill_material != null:
        fill_material.albedo_color = Color(0.20, 0.88, 0.48) if ratio > 0.55 else (Color(1.0, 0.67, 0.16) if ratio > 0.25 else Color(1.0, 0.22, 0.15))

func _update_damage_health_bar(delta: float) -> void:
    if not is_instance_valid(damage_health_bar_root):
        return
    damage_health_bar_timer = maxf(0.0, damage_health_bar_timer - delta)
    if dead or damage_health_bar_timer <= 0.0:
        damage_health_bar_root.visible = false
        return
    damage_health_bar_root.visible = true
    damage_health_bar_root.modulate.a = clampf(damage_health_bar_timer / 0.28, 0.0, 1.0) if damage_health_bar_timer < 0.28 else 1.0

func _trigger_damage_flash() -> void:
    if not is_instance_valid(damage_flash_ring):
        return
    damage_flash_timer = DAMAGE_FLASH_DURATION
    damage_flash_ring.visible = true
    damage_flash_ring.scale = Vector3.ONE * 0.82

func _update_damage_flash(delta: float) -> void:
    if not is_instance_valid(damage_flash_ring):
        return
    damage_flash_timer = maxf(0.0, damage_flash_timer - delta)
    if damage_flash_timer <= 0.0:
        damage_flash_ring.visible = false
        return
    var progress := 1.0 - damage_flash_timer / DAMAGE_FLASH_DURATION
    damage_flash_ring.scale = Vector3.ONE * lerpf(0.82, 1.22, progress)

func _update_visual_motion(delta: float) -> void:
    if not is_instance_valid(visual_rig):
        return
    if dead:
        visual_rig.position = Vector3.ZERO
        visual_rig.rotation = Vector3.ZERO
        if is_instance_valid(visual_left_arm):
            visual_left_arm.rotation = Vector3.ZERO
        if is_instance_valid(visual_right_arm):
            visual_right_arm.rotation = Vector3.ZERO
        if is_instance_valid(visual_left_leg):
            visual_left_leg.rotation = Vector3.ZERO
        if is_instance_valid(visual_right_leg):
            visual_right_leg.rotation = Vector3.ZERO
        return

    visual_hit_recoil = move_toward(visual_hit_recoil, 0.0, delta * 3.8)
    var horizontal_velocity := velocity
    horizontal_velocity.y = 0.0
    var speed_ratio := clampf(horizontal_velocity.length() / SPRINT_SPEED, 0.0, 1.0)
    visual_motion_time += delta * lerpf(1.8, 9.0, speed_ratio)
    var local_velocity := global_transform.basis.inverse() * horizontal_velocity
    var stride := sin(visual_motion_time)
    var bob := absf(stride) * 0.035 * speed_ratio
    # A very small idle breathing cycle keeps stationary combatants from looking
    # frozen. It fades out as movement begins and only animates the visual rig.
    var idle_breath := sin(visual_motion_time * 0.72 + float(combat_slot) * 0.83) * 0.012 * (1.0 - speed_ratio)
    # A restrained body bob and lateral lean add life to the low-poly model.
    # Only the visual child moves; the CharacterBody3D collider stays untouched.
    var target_position := Vector3(0.0, bob + idle_breath, 0.0)
    var target_rotation := Vector3(
        -0.018 * speed_ratio + idle_breath * 0.35 + visual_hit_recoil * 0.12,
        0.0,
        clampf(-local_velocity.x * 0.025, -0.055, 0.055)
    )
    visual_rig.position = visual_rig.position.lerp(target_position, minf(delta * 12.0, 1.0))
    visual_rig.rotation = visual_rig.rotation.lerp(target_rotation, minf(delta * 10.0, 1.0))

    # Alternating limb swing adds a readable walk/run cycle. These transforms
    # affect only named render meshes; the body collider and weapon logic stay
    # independent. Keep arm motion restrained so the rifle silhouette remains
    # readable while moving.
    var leg_swing := sin(visual_motion_time) * 0.34 * speed_ratio
    var arm_swing := sin(visual_motion_time + PI) * 0.075 * speed_ratio
    var flinch_arm_offset := -visual_hit_recoil * 0.20
    if is_instance_valid(visual_left_leg):
        visual_left_leg.rotation.x = lerpf(visual_left_leg.rotation.x, leg_swing, minf(delta * 12.0, 1.0))
    if is_instance_valid(visual_right_leg):
        visual_right_leg.rotation.x = lerpf(visual_right_leg.rotation.x, -leg_swing, minf(delta * 12.0, 1.0))
    if is_instance_valid(visual_left_arm):
        visual_left_arm.rotation.x = lerpf(visual_left_arm.rotation.x, arm_swing + flinch_arm_offset, minf(delta * 10.0, 1.0))
    if is_instance_valid(visual_right_arm):
        visual_right_arm.rotation.x = lerpf(visual_right_arm.rotation.x, -arm_swing + flinch_arm_offset, minf(delta * 10.0, 1.0))


func _create_bot_muzzle_flash() -> void:
    muzzle_flash = MeshInstance3D.new()
    muzzle_flash.name = "BotMuzzleFlash"
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.075
    flash_mesh.height = 0.15
    muzzle_flash.mesh = flash_mesh
    muzzle_flash.position = Vector3(0.18, -0.02, -1.08)
    muzzle_flash.scale = Vector3(0.65, 0.75, 1.65)
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color = Color(1.0, 0.68, 0.24)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.28, 0.035)
    flash_material.emission_energy_multiplier = 2.6
    muzzle_flash.material_override = flash_material
    muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # A compact starburst makes enemy fire readable at a glance. These are
    # child meshes of the existing timed flash: no particles, lights, or physics.
    var ray_material := StandardMaterial3D.new()
    ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ray_material.albedo_color = Color(1.0, 0.86, 0.48, 0.94)
    ray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ray_material.emission_enabled = true
    ray_material.emission = Color(1.0, 0.42, 0.08)
    ray_material.emission_energy_multiplier = 2.2

    var horizontal_ray := MeshInstance3D.new()
    var horizontal_mesh := BoxMesh.new()
    horizontal_mesh.size = Vector3(0.28, 0.022, 0.022)
    horizontal_ray.mesh = horizontal_mesh
    horizontal_ray.material_override = ray_material
    horizontal_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.add_child(horizontal_ray)

    var vertical_ray := MeshInstance3D.new()
    var vertical_mesh := BoxMesh.new()
    vertical_mesh.size = Vector3(0.022, 0.19, 0.022)
    vertical_ray.mesh = vertical_mesh
    vertical_ray.material_override = ray_material
    vertical_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.add_child(vertical_ray)

    for diagonal_sign in [-1.0, 1.0]:
        var diagonal_ray := MeshInstance3D.new()
        var diagonal_mesh := BoxMesh.new()
        diagonal_mesh.size = Vector3(0.18, 0.016, 0.020)
        diagonal_ray.mesh = diagonal_mesh
        diagonal_ray.rotation.z = deg_to_rad(32.0 * diagonal_sign)
        diagonal_ray.material_override = ray_material
        diagonal_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        muzzle_flash.add_child(diagonal_ray)

    muzzle_flash.visible = false
    add_child(muzzle_flash)

func _trigger_bot_muzzle_flash() -> void:
    if not is_instance_valid(muzzle_flash):
        return
    muzzle_flash_timer = MUZZLE_FLASH_DURATION
    muzzle_flash.visible = true

func _physics_process(delta: float) -> void:
    _update_visual_motion(delta)
    _update_damage_flash(delta)
    _update_damage_health_bar(delta)
    muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
    if muzzle_flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
        muzzle_flash.visible = false
    var network_session = main.get("network_session") if main != null else null
    if network_session != null and network_session.is_online and not network_session.is_server:
        _update_network_presentation(delta)
        return
    if dead:
        return

    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    peek_timer = maxf(0.0, peek_timer - delta)
    peek_hold_timer = maxf(0.0, peek_hold_timer - delta)
    combat_decision_timer = maxf(0.0, combat_decision_timer - delta)
    recently_hit_timer = maxf(0.0, recently_hit_timer - delta)
    combat_reposition_timer = maxf(0.0, combat_reposition_timer - delta)
    route_replan_timer = maxf(0.0, route_replan_timer - delta)
    tactical_memory_timer = maxf(0.0, tactical_memory_timer - delta)
    burst_pause = maxf(0.0, burst_pause - delta)
    strafe_time = maxf(0.0, strafe_time - delta)
    if strafe_time <= 0.0:
        strafe_time = STRAFE_INTERVAL
        strafe_sign *= -1.0
    target = main.get("player")
    if not is_instance_valid(target):
        return

    var memory = main.call("_get_bot_tactical_memory", self)
    if memory is Dictionary:
        tactical_memory_position = memory.get("position", Vector3.ZERO)
        tactical_memory_timer = float(memory.get("time_left", 0.0))
        tactical_memory_revision = int(memory.get("revision", -1))

    var director = main.call("_get_bot_combat_director", self)
    if director is Dictionary:
        combat_director_phase = str(director.get("phase", "IDLE"))
        combat_director_command = str(director.get("command", "HOLD"))
        combat_director_revision = int(director.get("revision", -1))
        combat_director_fire_ready = bool(director.get("fire_ready", false))
        squad_threat_state = str(director.get("threat", "LOST"))
        squad_threat_position = director.get("threat_position", Vector3.ZERO)
        var next_threat_revision := int(director.get("threat_revision", -1))
        if next_threat_revision != applied_threat_revision:
            applied_threat_revision = next_threat_revision
            combat_decision_timer = 0.0
            combat_reposition_timer = 0.0
            combat_reposition_goal = Vector3.ZERO
            fire_cooldown = 0.0
            burst_remaining = 0
            burst_pause = 0.0
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
            if squad_threat_state != "CONTACT":
                combat_intent = "HOLD"
        squad_threat_revision = next_threat_revision
        var next_role_revision := int(director.get("role_revision", -1))
        if next_role_revision != combat_role_revision:
            combat_role_revision = next_role_revision
            combat_director_fire_ready = false
            combat_reposition_timer = 0.0
            combat_reposition_goal = Vector3.ZERO
            burst_remaining = 0
            burst_pause = 0.0
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0

    _update_state()
    if state != last_state:
        close_retreat_route_active = false
        route.clear()
        route_index = 0
        route_goal = Vector3.ZERO
        route_failed_goal = Vector3.ZERO
        route_replan_timer = 0.0
        current_goal = Vector3.ZERO
        if state != "BOMB_COVER":
            bomb_cover_goal = Vector3.ZERO
            bomb_cover_site = ""
            bomb_cover_revision = -1
        if state != "COVER" or combat_intent != "RETREAT":
            retreat_cover_goal = Vector3.ZERO
        if state != "FLANK":
            flank_goal_revision = -1
        if state != "SEARCH":
            search_goal = Vector3.ZERO
            search_revision = -1
        last_state = state
    _update_goal()
    _move_toward_goal(delta)

    var director_can_fire := combat_director_fire_ready or combat_assignment == "PRESSURE"
    var threat_allows_fire := squad_threat_state == "CONTACT"
    var has_fire_los := _has_line_of_sight()
    var fire_state := state == "ATTACK" or state == "FLANK" or state == "SUPPRESS" or state == "PEEK" or state == "BOMB_COVER" or state == "REPOSITION"
    if not threat_allows_fire or not has_fire_los or not fire_state:
        burst_remaining = 0
        burst_pause = 0.0
    elif director_can_fire:
        _fire()

    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    move_and_slide()

func _update_state() -> void:
    var objective_state := str(main.get("objective_state"))
    if objective_state == "PLANTED":
        var active_defuser = main.get("active_defuser")
        if is_instance_valid(active_defuser) and active_defuser == self:
            state = "DEFUSE"
        else:
            state = "BOMB_COVER"
        return
    if objective_state == "DROPPED":
        # The RED team cannot recover the BLUE bomb. The assigned objective
        # defender instead denies the pickup while the remaining bots keep
        # their normal defensive/combat responsibilities.
        if combat_assignment == "SUPPORT":
            combat_intent = "HOLD"
            state = "BOMB_COVER"
        else:
            state = "DEFEND"
        return

    var squad_contact_active := bool(main.call("_is_squad_contact_active"))
    if squad_threat_state == "LOST" and not squad_contact_active and combat_intent != "RETREAT":
        state = "DEFEND"
        return

    if squad_threat_state == "SEARCHING" and not squad_contact_active and combat_intent == "HOLD" and not _has_line_of_sight():
        state = "SEARCH"
        return

    if squad_threat_state == "TRACKED" and not squad_contact_active and combat_intent != "RETREAT" and not _has_line_of_sight():
        state = "REENGAGE"
        return

    if squad_contact_active and combat_intent != "RETREAT":
        if combat_assignment == "SUPPORT":
            state = "SUPPRESS"
            return
        if combat_assignment == "FLANK":
            state = "FLANK"
            return
        if not _has_line_of_sight():
            state = "ATTACK" if combat_intent == "PUSH" else "REENGAGE"
            return

    if bool(main.call("_is_squad_search_active")) and combat_intent == "HOLD" and not _has_line_of_sight():
        state = "SEARCH"
        return

    if state == "FLANK":
        if combat_intent == "RETREAT":
            state = "COVER"
            route.clear()
            route_index = 0
            return
        if not bool(main.call("_is_squad_contact_active")):
            state = "SEARCH" if bool(main.call("_is_squad_search_active")) else "DEFEND"
            route.clear()
            route_index = 0
            return
        if combat_director_command != "FLANK":
            state = "ATTACK" if _has_line_of_sight() else "REENGAGE"
            route.clear()
            route_index = 0
        return

    if state == "SUPPRESS":
        if combat_intent == "RETREAT":
            state = "COVER"
            route.clear()
            route_index = 0
            return
        if not bool(main.call("_is_squad_contact_active")):
            state = "SEARCH" if bool(main.call("_is_squad_search_active")) else "DEFEND"
            route.clear()
            route_index = 0
            return
        if not _has_line_of_sight() and combat_director_phase == "LOST":
            state = "REENGAGE"
            route.clear()
            route_index = 0
        return

    if state == "REENGAGE":
        if _has_line_of_sight():
            state = "ATTACK" if combat_intent == "PUSH" else "DEFEND"
            route.clear()
            route_index = 0
            return
        if not bool(main.call("_is_squad_contact_active")):
            state = "SEARCH" if bool(main.call("_is_squad_search_active")) else "DEFEND"
            route.clear()
            route_index = 0
            return
        return

    if state == "SEARCH":
        if _has_line_of_sight():
            state = "ATTACK" if combat_intent == "PUSH" else "DEFEND"
            route.clear()
            route_index = 0
            return
        if not bool(main.call("_is_squad_search_active")):
            state = "DEFEND"
            route.clear()
            route_index = 0
            return
        return

    if state == "REPOSITION":
        if combat_intent == "RETREAT":
            state = "COVER"
            combat_reposition_goal = Vector3.ZERO
            route.clear()
            route_index = 0
        return

    if combat_decision_timer <= 0.0:
        _decide_combat_intent()
        combat_decision_timer = COMBAT_DECISION_INTERVAL

    if state == "PEEK":
        if combat_intent == "RETREAT":
            state = "COVER"
            route.clear()
            route_index = 0
        elif peek_timer <= 0.0:
            state = "ATTACK" if combat_intent == "PUSH" else "DEFEND"
            route.clear()
            route_index = 0
        return

    if state == "COVER":
        if combat_intent == "PUSH":
            state = "ATTACK"
            route.clear()
            route_index = 0
        return

    if combat_intent == "RETREAT":
        state = "COVER"
    elif combat_intent == "PUSH":
        state = "ATTACK"
    else:
        state = "DEFEND"

func _decide_combat_intent() -> void:
    var distance := global_position.distance_to(target.global_position)
    var has_los := _has_line_of_sight()

    if health <= RETREAT_HEALTH_THRESHOLD:
        combat_intent = "RETREAT"
        return

    if recently_hit_timer > 0.0 and health <= 60:
        combat_intent = "RETREAT"
        return

    if distance > DETECTION_RANGE:
        combat_intent = "HOLD"
        return

    if squad_threat_state == "SEARCHING":
        combat_intent = "HOLD"
        return

    if squad_threat_state == "TRACKED" and not has_los:
        combat_intent = "HOLD"
        return

    if squad_threat_state == "LOST":
        combat_intent = "HOLD"
        return

    var aggression := float(main.call("_threat_role_aggression", self))

    if combat_assignment == "SUPPORT":
        var support_range := lerpf(PUSH_DISTANCE - 1.0, PUSH_DISTANCE + 1.0, aggression)
        var support_health := int(lerpf(65.0, float(PUSH_HEALTH_THRESHOLD), aggression))
        if has_los and distance <= support_range and health >= support_health:
            combat_intent = "PUSH"
            return
        combat_intent = "HOLD"
        return

    if combat_assignment == "PRESSURE":
        var pressure_range := lerpf(PUSH_DISTANCE, PUSH_DISTANCE + 4.0, aggression)
        var pressure_health := int(lerpf(50.0, float(RETREAT_HEALTH_THRESHOLD), aggression))
        if has_los and distance <= pressure_range and health >= pressure_health:
            combat_intent = "PUSH"
            return
        combat_intent = "HOLD"
        return

    if combat_assignment == "FLANK":
        var flank_range := lerpf(PUSH_DISTANCE, HOLD_DISTANCE, aggression)
        var flank_health := int(lerpf(50.0, float(PUSH_HEALTH_THRESHOLD), aggression))
        if has_los and distance <= flank_range and health >= flank_health:
            combat_intent = "PUSH"
            return
        combat_intent = "HOLD"
        return

    if has_los and distance <= PUSH_DISTANCE and health >= PUSH_HEALTH_THRESHOLD:
        combat_intent = "PUSH"
        return

    if role == "ROAMER" and has_los and distance <= HOLD_DISTANCE and health >= PUSH_HEALTH_THRESHOLD:
        combat_intent = "PUSH"
        return

    if role != "ROAMER" and has_los and distance <= HOLD_DISTANCE and health >= PUSH_HEALTH_THRESHOLD:
        var defend_site: Vector3 = main.get("bomb_site_a") if role == "DEFENDER_A" else main.get("bomb_site_b")
        if global_position.distance_to(defend_site) <= SITE_RADIUS * 2.5 and distance <= PUSH_DISTANCE:
            combat_intent = "PUSH"
            return

    combat_intent = "HOLD"

func _update_goal() -> void:
    var objective_state := str(main.get("objective_state"))

    if state == "BOMB_COVER" and objective_state == "DROPPED":
        var dropped_position: Vector3 = main.get("dropped_bomb_position")
        if dropped_position == Vector3.ZERO:
            current_goal = Vector3.ZERO
            route.clear()
            route_index = 0
            return
        var keep_dropped_guard := current_goal != Vector3.ZERO
        keep_dropped_guard = keep_dropped_guard and current_goal.distance_to(dropped_position) <= 8.0
        keep_dropped_guard = keep_dropped_guard and global_position.distance_to(current_goal) <= 18.0
        keep_dropped_guard = keep_dropped_guard and main.call("_bot_has_navigation_path", self, current_goal)
        if not keep_dropped_guard:
            current_goal = dropped_position
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return
    if state == "BOMB_COVER" and objective_state == "PLANTED":
        var planted_site := str(main.get("planted_site"))
        var defense_revision := int(main.get("bomb_defense_revision"))
        var site_position: Vector3 = main.get("bomb_site_a") if planted_site == "A" else main.get("bomb_site_b")
        var keep_bomb_cover := bomb_cover_goal != Vector3.ZERO
        keep_bomb_cover = keep_bomb_cover and bomb_cover_site == planted_site
        keep_bomb_cover = keep_bomb_cover and bomb_cover_revision == defense_revision
        keep_bomb_cover = keep_bomb_cover and global_position.distance_to(bomb_cover_goal) <= 18.0
        keep_bomb_cover = keep_bomb_cover and bomb_cover_goal.distance_to(site_position) <= 10.0
        keep_bomb_cover = keep_bomb_cover and bomb_cover_goal.distance_to(target.global_position) >= 6.0
        keep_bomb_cover = keep_bomb_cover and main.call("_bot_has_navigation_path", self, bomb_cover_goal)
        keep_bomb_cover = keep_bomb_cover and main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), bomb_cover_goal)
        if not keep_bomb_cover:
            var selected_cover = main.call("_select_bot_bomb_cover", site_position, target.global_position, self)
            bomb_cover_goal = selected_cover if selected_cover is Vector3 else Vector3.ZERO
            bomb_cover_site = planted_site
            bomb_cover_revision = defense_revision
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_replan_timer = 0.0
        current_goal = bomb_cover_goal if bomb_cover_goal != Vector3.ZERO else site_position
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "DEFUSE" and objective_state == "PLANTED":
        var planted_site := str(main.get("planted_site"))
        current_goal = main.get("bomb_site_a") if planted_site == "A" else main.get("bomb_site_b")
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "REENGAGE":
        var contact = main.call("_get_bot_squad_contact", self)
        var contact_revision := int(contact.get("revision", -1)) if contact is Dictionary else -1
        var target_position := Vector3.ZERO
        if contact is Dictionary:
            target_position = contact.get("position", Vector3.ZERO)
        if target_position == Vector3.ZERO and squad_threat_state == "TRACKED":
            var threat = main.call("_get_squad_threat")
            if threat is Dictionary:
                target_position = threat.get("position", Vector3.ZERO)
                contact_revision = int(threat.get("revision", contact_revision))
        if target_position == Vector3.ZERO:
            target_position = main.call("_get_bot_squad_engagement_target", self)
        if target_position == Vector3.ZERO:
            current_goal = Vector3.ZERO
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_replan_timer = 0.0
            return
        if squad_contact_revision != contact_revision or current_goal == Vector3.ZERO or current_goal.distance_to(target_position) >= ROUTE_GOAL_CHANGE_DISTANCE:
            current_goal = target_position
            squad_contact_position = current_goal
            squad_contact_revision = contact_revision
            route.clear()
            route_index = 0
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        else:
            current_goal = squad_contact_position
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "SEARCH":
        var active_search_revision := int(main.get("squad_search_revision"))
        if search_revision != active_search_revision or search_goal == Vector3.ZERO:
            var selected_search_goal = main.call("_get_bot_squad_search_goal", self)
            search_goal = selected_search_goal if selected_search_goal is Vector3 else Vector3.ZERO
            search_revision = active_search_revision
            route.clear()
            route_index = 0
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        current_goal = search_goal
        if current_goal == Vector3.ZERO:
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
            return
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "FLANK":
        var flank_revision := maxi(combat_director_revision, squad_threat_revision)
        if flank_goal_revision != flank_revision or current_goal == Vector3.ZERO:
            var flank_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
            if flank_target == Vector3.ZERO:
                flank_target = target.global_position
            var flank_position = main.call("_select_bot_attack_position", self, flank_target, combat_slot)
            if flank_position is Vector3 and flank_position != Vector3.ZERO:
                current_goal = flank_position
            else:
                current_goal = flank_target
            flank_goal_revision = flank_revision
            route.clear()
            route_index = 0
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "SUPPRESS":
        var suppress_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
        if suppress_target == Vector3.ZERO:
            suppress_target = target.global_position
        var suppress_distance := global_position.distance_to(suppress_target)
        if suppress_distance > OPTIMAL_RANGE + 2.0:
            current_goal = suppress_target
            _ensure_route(current_goal)
        else:
            current_goal = global_position
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        return

    if state == "REPOSITION":
        current_goal = combat_reposition_goal
        if current_goal == Vector3.ZERO:
            state = "ATTACK"
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            return
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "ATTACK":
        if combat_reposition_timer <= 0.0:
            var reposition_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
            var attack_position = main.call("_select_bot_attack_position", self, reposition_target, combat_slot)
            if attack_position is Vector3 and attack_position != Vector3.ZERO and global_position.distance_to(attack_position) >= COMBAT_REPOSITION_MIN_DISTANCE:
                combat_reposition_goal = attack_position
                combat_reposition_timer = COMBAT_REPOSITION_INTERVAL
                state = "REPOSITION"
                route.clear()
                route_index = 0
                _ensure_route(combat_reposition_goal)
                return
            combat_reposition_timer = COMBAT_REPOSITION_INTERVAL
        var tactical_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
        if tactical_target == Vector3.ZERO:
            tactical_target = target.global_position
        var has_tactical_los := _has_line_of_sight()
        if not has_tactical_los:
            # PUSH can legitimately enter ATTACK while the target is behind
            # cover. Keep the bot on the tactical navigation target instead of
            # strafing directly through the blocking geometry.
            current_goal = tactical_target
            _ensure_route(current_goal)
            return
        var distance := global_position.distance_to(tactical_target)
        if distance > OPTIMAL_RANGE:
            current_goal = tactical_target
            _ensure_route(current_goal)
        else:
            current_goal = global_position
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
        return

    if state == "COVER" or state == "PEEK":
        if combat_intent == "RETREAT":
            var keep_retreat_cover := retreat_cover_goal != Vector3.ZERO
            keep_retreat_cover = keep_retreat_cover and global_position.distance_to(retreat_cover_goal) <= 18.0
            keep_retreat_cover = keep_retreat_cover and retreat_cover_goal.distance_to(target.global_position) <= 20.0
            keep_retreat_cover = keep_retreat_cover and retreat_cover_goal.distance_to(target.global_position) >= 5.0
            keep_retreat_cover = keep_retreat_cover and main.call("_bot_has_navigation_path", self, retreat_cover_goal)
            keep_retreat_cover = keep_retreat_cover and main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), retreat_cover_goal)
            if not keep_retreat_cover:
                var retreat_cover = main.call("_select_bot_combat_cover", self, target.global_position, 12.0)
                retreat_cover_goal = retreat_cover if retreat_cover is Vector3 else Vector3.ZERO
                route.clear()
                route_index = 0
                route_goal = Vector3.ZERO
                route_replan_timer = 0.0
            if retreat_cover_goal != Vector3.ZERO:
                current_goal = retreat_cover_goal
                cover_index = -1
                if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
                    route.clear()
                    route_index = 0
                    return
                _ensure_route(current_goal)
                return
        var previous_cover_index := cover_index
        _select_cover_point()
        if cover_index >= 0:
            if cover_index != previous_cover_index:
                route.clear()
                route_index = 0
                route_goal = Vector3.ZERO
                route_failed_goal = Vector3.ZERO
                route_replan_timer = 0.0
            var cover_data: Dictionary = main.get("cover_points")[cover_index]
            current_goal = cover_data["cover"] if state == "COVER" else cover_data["peek"]
            _ensure_route(current_goal)
        else:
            current_goal = Vector3.ZERO
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_replan_timer = 0.0
        return

    var defend_site := "A" if role == "DEFENDER_A" else "B"
    if role == "ROAMER":
        defend_site = "B" if int(Time.get_ticks_msec() / 5000.0) % 2 == 0 else "A"
    var site_position: Vector3 = main.get("bomb_site_a") if defend_site == "A" else main.get("bomb_site_b")

    var keep_current_defend_goal := current_goal != Vector3.ZERO
    keep_current_defend_goal = keep_current_defend_goal and global_position.distance_to(current_goal) <= 18.0
    keep_current_defend_goal = keep_current_defend_goal and current_goal.distance_to(site_position) <= 10.0
    keep_current_defend_goal = keep_current_defend_goal and current_goal.distance_to(target.global_position) >= 5.0
    keep_current_defend_goal = keep_current_defend_goal and main.call("_bot_has_navigation_path", self, current_goal)
    var defend_goal_has_cover: bool = bool(main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), current_goal))
    var defend_goal_is_site_fallback := current_goal.is_equal_approx(site_position)
    keep_current_defend_goal = keep_current_defend_goal and (defend_goal_has_cover or defend_goal_is_site_fallback)

    if not keep_current_defend_goal:
        var tactical_cover = main.call("_select_bot_site_cover", self, site_position, target.global_position, role)
        if tactical_cover is Vector3 and tactical_cover != Vector3.ZERO:
            current_goal = tactical_cover
        else:
            current_goal = site_position
        route.clear()
        route_index = 0
        route_goal = Vector3.ZERO
        route_replan_timer = 0.0

    if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
        route.clear()
        route_index = 0
        return

    _ensure_route(current_goal)
func _select_cover_point() -> void:
    var points: Array = main.get("cover_points")
    if points.is_empty():
        cover_index = -1
        return
    if cover_index >= 0 and cover_index < points.size():
        var current: Dictionary = points[cover_index]
        var current_cover: Vector3 = current["cover"]
        var current_peek: Vector3 = current["peek"]
        var current_player_distance := current_cover.distance_to(target.global_position)
        var current_cover_valid := global_position.distance_to(current_cover) <= 18.0
        current_cover_valid = current_cover_valid and current_player_distance >= 5.0
        current_cover_valid = current_cover_valid and main.call("_bot_has_navigation_path", self, current_cover)
        if state == "PEEK":
            current_cover_valid = current_cover_valid and main.call("_bot_has_navigation_path", self, current_peek)
        current_cover_valid = current_cover_valid and main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), current_cover)
        current_cover_valid = current_cover_valid and not main.call("_has_obstacle_between", current_peek, target.global_position + Vector3(0, 1.0, 0))
        if current_cover_valid:
            return

    var best := -1
    var best_score := INF
    for i in points.size():
        var data: Dictionary = points[i]
        var cover_position: Vector3 = data["cover"]
        var distance := global_position.distance_to(cover_position)
        if distance > 18.0:
            continue
        var peek_position: Vector3 = data["peek"]
        if not main.call("_bot_has_navigation_path", self, cover_position):
            continue
        if state == "PEEK" and not main.call("_bot_has_navigation_path", self, peek_position):
            continue
        var player_distance := cover_position.distance_to(target.global_position)
        if player_distance < 5.0:
            continue
        if not main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), cover_position):
            continue
        if main.call("_has_obstacle_between", peek_position, target.global_position + Vector3(0, 1.0, 0)):
            continue
        var score := distance + absf(player_distance - OPTIMAL_RANGE) * 0.25
        if score < best_score:
            best_score = score
            best = i
    cover_index = best

func _ensure_route(goal: Vector3) -> void:
    var goal_changed := route_goal == Vector3.ZERO or route_goal.distance_to(goal) >= ROUTE_GOAL_CHANGE_DISTANCE
    var route_finished := route.is_empty() or route_index >= route.size()
    var failed_goal_matches := route_failed_goal != Vector3.ZERO and route_failed_goal.distance_to(goal) < ROUTE_GOAL_CHANGE_DISTANCE
    if not goal_changed and failed_goal_matches and route_replan_timer > 0.0:
        return
    if not goal_changed and not route_finished and route_replan_timer > 0.0:
        return

    route = main.call("_find_navigation_route", global_position, goal)
    route_index = 0
    route_goal = goal
    route_failed_goal = goal if route.is_empty() else Vector3.ZERO
    route_replan_timer = ROUTE_REPLAN_INTERVAL

func _move_toward_goal(delta: float) -> void:
    if state == "REPOSITION":
        var reposition_offset := combat_reposition_goal - global_position
        reposition_offset.y = 0.0
        if reposition_offset.length() <= COVER_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var reposition_look := (target.global_position - global_position).normalized()
            look_at(global_position + Vector3(reposition_look.x, 0.0, reposition_look.z), Vector3.UP)
            state = "ATTACK"
            combat_reposition_goal = Vector3.ZERO
            route.clear()
            route_index = 0
            return

    if state == "BOMB_COVER" and str(main.get("objective_state")) == "DROPPED":
        var dropped_position: Vector3 = main.get("dropped_bomb_position")
        if dropped_position != Vector3.ZERO:
            var dropped_offset := current_goal - global_position
            dropped_offset.y = 0.0
            if dropped_offset.length() <= WAYPOINT_REACHED:
                velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
                velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
                var guard_look := (target.global_position - global_position).normalized()
                look_at(global_position + Vector3(guard_look.x, 0.0, guard_look.z), Vector3.UP)
                if _has_line_of_sight():
                    var side := Vector3(-guard_look.z, 0.0, guard_look.x) * strafe_sign
                    velocity.x = move_toward(velocity.x, side.x * 0.55, 5.0 * delta)
                    velocity.z = move_toward(velocity.z, side.z * 0.55, 5.0 * delta)
                return
    if state == "BOMB_COVER" and str(main.get("objective_state")) == "PLANTED":
        var bomb_cover_offset := current_goal - global_position
        bomb_cover_offset.y = 0.0
        if bomb_cover_offset.length() <= WAYPOINT_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var bomb_look := (target.global_position - global_position).normalized()
            look_at(global_position + Vector3(bomb_look.x, 0.0, bomb_look.z), Vector3.UP)
            if _has_line_of_sight():
                var side := Vector3(-bomb_look.z, 0.0, bomb_look.x) * strafe_sign
                velocity.x = move_toward(velocity.x, side.x * 0.8, 6.0 * delta)
                velocity.z = move_toward(velocity.z, side.z * 0.8, 6.0 * delta)
            return

    if state == "FLANK":
        var flank_offset := current_goal - global_position
        flank_offset.y = 0.0
        if flank_offset.length() <= WAYPOINT_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var flank_look := (target.global_position - global_position).normalized()
            look_at(global_position + Vector3(flank_look.x, 0.0, flank_look.z), Vector3.UP)
            return

    if state == "REENGAGE":
        var reengage_offset := current_goal - global_position
        reengage_offset.y = 0.0
        if reengage_offset.length() <= WAYPOINT_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var reengage_look := (current_goal - global_position).normalized()
            look_at(global_position + Vector3(reengage_look.x, 0.0, reengage_look.z), Vector3.UP)
            return

    if state == "SEARCH":
        var search_offset := current_goal - global_position
        search_offset.y = 0.0
        if search_offset.length() <= WAYPOINT_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var search_look := (current_goal - global_position).normalized()
            look_at(global_position + Vector3(search_look.x, 0.0, search_look.z), Vector3.UP)
            return

    if state == "ATTACK":
        var distance := global_position.distance_to(target.global_position)
        var attack_has_los := _has_line_of_sight()
        if attack_has_los and distance <= OPTIMAL_RANGE and distance >= MIN_COMBAT_RANGE:
            if close_retreat_route_active:
                route.clear()
                route_index = 0
                route_goal = Vector3.ZERO
                route_replan_timer = 0.0
                close_retreat_route_active = false
            var to_target := (target.global_position - global_position).normalized()
            var strafe := Vector3(-to_target.z, 0.0, to_target.x) * strafe_sign
            velocity.x = move_toward(velocity.x, strafe.x * 1.5, 10.0 * delta)
            velocity.z = move_toward(velocity.z, strafe.z * 1.5, 10.0 * delta)
            look_at(global_position + Vector3(to_target.x, 0.0, to_target.z), Vector3.UP)
            return
        if not attack_has_los and close_retreat_route_active:
            # A lost line of sight ends the close-range retreat. Discard its
            # short route so pursuit can resume toward the squad's tactical
            # target instead of following an obsolete retreat waypoint.
            close_retreat_route_active = false
            route.clear()
            route_index = 0
            route_goal = Vector3.ZERO
            route_failed_goal = Vector3.ZERO
            route_replan_timer = 0.0
        if attack_has_los and distance < MIN_COMBAT_RANGE:
            var away := (global_position - target.global_position).normalized()
            var retreat_goal := global_position + away * 5.0
            # Close-range retreat must take over the route immediately. Without
            # this handoff, a still-valid long-range attack route can be reused
            # for a few frames when its goal is near the retreat goal.
            if not close_retreat_route_active:
                route.clear()
                route_index = 0
                route_goal = Vector3.ZERO
                route_replan_timer = 0.0
                close_retreat_route_active = true
            _ensure_route(retreat_goal)
            if route.size() == 0:
                velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
                velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
                return
        if distance > OPTIMAL_RANGE:
            close_retreat_route_active = false
            # Long-range pursuit must use the same tactical target selected
            # by _update_goal(), including squad contact/memory positions.
            var pursuit_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
            if pursuit_target == Vector3.ZERO:
                pursuit_target = target.global_position
            _ensure_route(pursuit_target)
            if route.size() == 0:
                velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
                velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
                return

    if state == "COVER" or state == "PEEK":
        var destination: Vector3
        if combat_intent == "RETREAT" and retreat_cover_goal != Vector3.ZERO:
            destination = retreat_cover_goal
        else:
            if cover_index < 0:
                velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
                velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
                return
            var cover_data: Dictionary = main.get("cover_points")[cover_index]
            destination = cover_data["cover"] if state == "COVER" else cover_data["peek"]
        var cover_offset := destination - global_position
        cover_offset.y = 0.0
        if cover_offset.length() <= COVER_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var look_direction := (target.global_position - global_position).normalized()
            look_at(global_position + Vector3(look_direction.x, 0.0, look_direction.z), Vector3.UP)
            if state == "COVER":
                if combat_intent == "RETREAT":
                    return
                peek_timer = PEEK_TIME
                peek_hold_timer = PEEK_HOLD
                state = "PEEK"
                route.clear()
                route_index = 0
            elif peek_timer <= 0.0:
                state = "COVER" if health <= LOW_HEALTH_THRESHOLD else "ATTACK"
                route.clear()
                route_index = 0
            return

    if route.size() == 0:
        velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
        return

    if route_index >= route.size():
        velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
        return

    var waypoint: Vector3 = route[route_index]
    waypoint.y = global_position.y
    var offset := waypoint - global_position
    if offset.length() <= WAYPOINT_REACHED:
        var can_advance_waypoint := true
        if route_index == 0 and route.size() > 1:
            var next_waypoint: Vector3 = route[1]
            can_advance_waypoint = bool(main.call("_navigation_visible", global_position, next_waypoint))
        if not can_advance_waypoint:
            # The next waypoint is no longer visible from the bot. Keep the
            # route goal and throttle replanning instead of retrying A* every
            # frame against the same blocked route.
            route.clear()
            route_index = 0
            route_failed_goal = route_goal
            route_replan_timer = ROUTE_REPLAN_INTERVAL
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            return
        route_index += 1
        if route_index >= route.size():
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            return
        waypoint = route[route_index]
        waypoint.y = global_position.y
        offset = waypoint - global_position

    if not bool(main.call("_navigation_visible", global_position, waypoint)):
        # The current route segment is no longer traversable from the bot's
        # actual position. Replan from here instead of pushing through geometry.
        route.clear()
        route_index = 0
        route_failed_goal = route_goal
        route_replan_timer = ROUTE_REPLAN_INTERVAL
        velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
        return

    var direction := offset.normalized()
    var speed := SPRINT_SPEED if state == "DEFUSE" else MOVE_SPEED
    velocity.x = move_toward(velocity.x, direction.x * speed, 12.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 12.0 * delta)
    look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)

func apply_network_snapshot(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    var snapshot_round := int(snapshot.get("round_number", network_round_number))
    if network_round_number != snapshot_round:
        network_round_number = snapshot_round
        network_snapshot_age = 0.0
        network_snapshot_fresh = false
        velocity = Vector3.ZERO
        global_position = snapshot.get("position", global_position)
        dead = false
        visible = true
        if collision_shape:
            collision_shape.disabled = false
        collision_layer = 1
        collision_mask = 1
    network_target_position = snapshot.get("position", global_position)
    network_target_velocity = snapshot.get("velocity", Vector3.ZERO)
    network_target_yaw = float(snapshot.get("yaw", rotation.y))
    network_snapshot_age = 0.0
    network_snapshot_fresh = true
    var previous_health := health
    health = int(snapshot.get("health", health))
    if health < previous_health:
        _trigger_damage_flash()
        _spawn_damage_number(previous_health - health)
    var snapshot_dead := bool(snapshot.get("dead", false))
    state = str(snapshot.get("state", state))
    combat_assignment = str(snapshot.get("assignment", combat_assignment))
    if snapshot_dead and not dead:
        _spawn_elimination_effect()
        dead = true
        velocity = Vector3.ZERO
        visible = false
        if collision_shape:
            collision_shape.disabled = true
        collision_layer = 0
        collision_mask = 0
    elif not snapshot_dead and dead:
        dead = false
        visible = true
        if collision_shape:
            collision_shape.disabled = false
        collision_layer = 1
        collision_mask = 1

func _update_network_presentation(delta: float) -> void:
    if not network_snapshot_fresh:
        return
    network_snapshot_age += delta
    if network_snapshot_age <= NETWORK_EXTRAPOLATION_TIME:
        var predicted_position := network_target_position + network_target_velocity * network_snapshot_age
        if global_position.distance_to(predicted_position) > NETWORK_SNAP_DISTANCE:
            global_position = network_target_position
        else:
            global_position = global_position.lerp(predicted_position, minf(delta * 18.0, 1.0))
    else:
        global_position = global_position.lerp(network_target_position, minf(delta * 10.0, 1.0))
    velocity = network_target_velocity if network_snapshot_age <= NETWORK_SNAPSHOT_STALE_TIME else Vector3.ZERO
    rotation.y = lerp_angle(rotation.y, network_target_yaw, minf(delta * 16.0, 1.0))
    visible = not dead
    if network_snapshot_age > NETWORK_SNAPSHOT_STALE_TIME:
        velocity = Vector3.ZERO
func _has_line_of_sight() -> bool:
    var origin := global_position + Vector3(0, 1.0, 0)
    var target_position := target.global_position + Vector3(0, 0.5, 0)
    var query := PhysicsRayQueryParameters3D.create(origin, target_position)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider == target

func _fire() -> void:
    if not is_instance_valid(target):
        return
    var network_session = main.get("network_session") if main != null else null
    if network_session != null and network_session.is_online and not network_session.is_server:
        # Clients may animate/predict bot intent, but only the server may
        # apply authoritative bot damage to the player.
        return
    var distance_to_target := global_position.distance_to(target.global_position)
    if distance_to_target > FIRE_RANGE:
        burst_remaining = 0
        burst_pause = 0.0
        return
    if fire_cooldown > 0.0 or burst_pause > 0.0:
        return
    if burst_remaining <= 0:
        burst_remaining = BURST_SHOTS

    fire_cooldown = FIRE_DELAY
    burst_remaining -= 1
    _trigger_bot_muzzle_flash()

    var origin := global_position + Vector3(0, 1.0, 0)
    var aim := target.global_position + Vector3(0, 0.5, 0)
    if randf() > ACCURACY:
        aim += Vector3(randf_range(-0.45, 0.45), randf_range(-0.30, 0.30), randf_range(-0.45, 0.45))

    var query := PhysicsRayQueryParameters3D.create(origin, aim)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var tracer_end: Vector3 = hit.position if not hit.is_empty() else aim
    _spawn_bot_tracer(origin, tracer_end)
    if not hit.is_empty() and hit.collider == target:
        main.call("_apply_damage", DAMAGE, global_position)

    if burst_remaining <= 0:
        burst_pause = BURST_PAUSE

func _spawn_bot_tracer(start_position: Vector3, end_position: Vector3) -> void:
    # A brief, thin tracer makes incoming bot fire readable. It is a single
    # shadow-free mesh, capped by its short lifetime, and skipped in low-spec.
    if main == null or bool(main.get("low_spec_mode")):
        return
    var segment := end_position - start_position
    var length := segment.length()
    if length < 0.08:
        return
    var tracer := MeshInstance3D.new()
    tracer.name = "BotShotTracer"
    var tracer_mesh := CylinderMesh.new()
    tracer_mesh.top_radius = 0.008
    tracer_mesh.bottom_radius = 0.008
    tracer_mesh.height = length
    tracer.mesh = tracer_mesh
    tracer.global_position = (start_position + end_position) * 0.5
    tracer.quaternion = Quaternion(Vector3.UP, segment / length)
    var tracer_material := StandardMaterial3D.new()
    tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tracer_material.albedo_color = Color(1.0, 0.48, 0.20, 0.78)
    tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    tracer_material.emission_enabled = true
    tracer_material.emission = Color(1.0, 0.24, 0.06)
    tracer_material.emission_energy_multiplier = 1.35
    tracer.material_override = tracer_material
    tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # A narrow hot core layered inside the amber tracer improves contrast at
    # range while keeping the effect to two shadow-free meshes and no lights.
    var core := MeshInstance3D.new()
    core.name = "BotShotTracerCore"
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = 0.0035
    core_mesh.bottom_radius = 0.0035
    core_mesh.height = length
    core.mesh = core_mesh
    var core_material := StandardMaterial3D.new()
    core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    core_material.albedo_color = Color(1.0, 0.88, 0.58, 0.92)
    core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    core_material.emission_enabled = true
    core_material.emission = Color(1.0, 0.52, 0.16)
    core_material.emission_energy_multiplier = 1.7
    core.material_override = core_material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    tracer.add_child(core)

    main.add_child(tracer)
    get_tree().create_timer(0.075).timeout.connect(tracer.queue_free)

func take_damage(amount: int, source_id: String = "player") -> void:
    if dead:
        return
    last_damage_source_id = source_id
    var previous_health := health
    health = maxi(0, health - amount)
    _trigger_damage_flash()
    _spawn_damage_number(previous_health - health)
    _show_damage_health_bar()
    recently_hit_timer = RECENT_HIT_REACTION_TIME
    visual_hit_recoil = 1.0
    combat_reposition_timer = 0.0
    combat_reposition_goal = Vector3.ZERO
    route.clear()
    route_index = 0
    route_goal = Vector3.ZERO
    route_failed_goal = Vector3.ZERO
    route_replan_timer = 0.0
    if health == 0:
        _die()

func reset_target() -> void:
    if is_instance_valid(damage_popup_tween):
        damage_popup_tween.kill()
    if is_instance_valid(damage_popup):
        damage_popup.queue_free()
    damage_popup = null
    damage_popup_tween = null
    damage_popup_total = 0
    network_snapshot_fresh = false
    network_snapshot_age = 0.0
    network_round_number = 0
    network_target_position = Vector3.ZERO
    network_target_velocity = Vector3.ZERO
    network_target_yaw = 0.0
    health = max_health
    dead = false
    damage_health_bar_timer = 0.0
    if is_instance_valid(damage_health_bar_root):
        damage_health_bar_root.visible = false
    last_damage_source_id = ""
    visible = true
    collision_layer = 1
    collision_mask = 1
    if collision_shape:
        collision_shape.disabled = false
    route.clear()
    route_index = 0
    route_goal = Vector3.ZERO
    route_replan_timer = 0.0
    route_failed_goal = Vector3.ZERO
    close_retreat_route_active = false
    state = "DEFEND"
    last_state = "DEFEND"
    current_goal = Vector3.ZERO
    cover_index = -1
    bomb_cover_goal = Vector3.ZERO
    bomb_cover_site = ""
    bomb_cover_revision = -1
    peek_timer = 0.0
    peek_hold_timer = 0.0
    combat_intent = "HOLD"
    combat_assignment = "SUPPORT"
    combat_engagement = "READY"
    tactical_memory_position = Vector3.ZERO
    tactical_memory_timer = 0.0
    tactical_memory_revision = -1
    combat_decision_timer = 0.0
    recently_hit_timer = 0.0
    visual_hit_recoil = 0.0
    combat_reposition_timer = 0.0
    combat_reposition_goal = Vector3.ZERO
    retreat_cover_goal = Vector3.ZERO
    search_goal = Vector3.ZERO
    search_revision = -1
    squad_contact_position = Vector3.ZERO
    squad_contact_timer = 0.0
    squad_contact_revision = -1
    combat_director_phase = "IDLE"
    combat_director_command = "HOLD"
    squad_threat_state = "LOST"
    squad_threat_position = Vector3.ZERO
    squad_threat_revision = -1
    combat_director_revision = -1
    combat_role_revision = -1
    combat_director_fire_ready = false
    applied_threat_revision = -1
    flank_goal_revision = -1
    fire_cooldown = 0.0
    burst_remaining = 0
    burst_pause = 0.0
    strafe_time = STRAFE_INTERVAL
    strafe_sign = 1.0

func _die() -> void:
    _spawn_elimination_effect()
    dead = true
    visible = false
    if collision_shape:
        collision_shape.disabled = true
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    eliminated.emit(self)


func _spawn_elimination_effect() -> void:
    # A short amber-red pulse marks an elimination while keeping the bot
    # itself hidden and the original hitbox/gameplay state untouched.
    if not is_instance_valid(main):
        return
    var effect := Node3D.new()
    effect.name = "BotEliminationPulse"
    main.add_child(effect)
    effect.global_position = global_position + Vector3(0.0, 0.12, 0.0)

    var pulse := MeshInstance3D.new()
    pulse.name = "EliminationRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.42
    ring_mesh.outer_radius = 0.56
    ring_mesh.ring_segments = 12
    ring_mesh.radial_segments = 4
    pulse.mesh = ring_mesh
    pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var pulse_material := StandardMaterial3D.new()
    pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pulse_material.albedo_color = Color(1.0, 0.24, 0.07, 0.88)
    pulse_material.emission_enabled = true
    pulse_material.emission = Color(1.0, 0.12, 0.025)
    pulse_material.emission_energy_multiplier = 2.0
    pulse.material_override = pulse_material
    effect.add_child(pulse)

    var core := MeshInstance3D.new()
    core.name = "EliminationCore"
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.20
    core_mesh.height = 0.40
    core.mesh = core_mesh
    core.material_override = pulse_material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    effect.add_child(core)

    effect.scale = Vector3(0.35, 0.35, 0.35)
    var tween := effect.create_tween().set_parallel(true)
    tween.tween_property(effect, "scale", Vector3(1.8, 1.8, 1.8), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(pulse_material, "albedo_color:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.finished.connect(effect.queue_free)