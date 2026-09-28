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

var team := "RED"
var max_health := 100
var health := 100
var dead := false
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

func _ready() -> void:
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
    main = get_parent()
    health = max_health
    target = main.get("player")

func _physics_process(delta: float) -> void:
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

    _update_state()
    if state != last_state:
        close_retreat_route_active = false
        route.clear()
        route_index = 0
        route_goal = Vector3.ZERO
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
        combat_intent = "HOLD"
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
        var defend_site := main.get("bomb_site_a") if role == "DEFENDER_A" else main.get("bomb_site_b")
        if global_position.distance_to(defend_site) <= SITE_RADIUS * 2.5 and distance <= PUSH_DISTANCE:
            combat_intent = "PUSH"
            return

    combat_intent = "HOLD"

func _update_goal() -> void:
    var objective_state := str(main.get("objective_state"))

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
        if squad_contact_revision != contact_revision or current_goal == Vector3.ZERO or current_goal.distance_to(target_position) >= ROUTE_GOAL_CHANGE_DISTANCE:
            current_goal = target_position
            squad_contact_position = current_goal
            squad_contact_revision = contact_revision
            route.clear()
            route_index = 0
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
        current_goal = search_goal
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
            var flank_position = main.call("_select_bot_attack_position", self, flank_target, combat_slot)
            if flank_position is Vector3 and flank_position != Vector3.ZERO:
                current_goal = flank_position
            else:
                current_goal = flank_target
            flank_goal_revision = flank_revision
            route.clear()
            route_index = 0
        if global_position.distance_to(current_goal) <= WAYPOINT_REACHED:
            route.clear()
            route_index = 0
            return
        _ensure_route(current_goal)
        return

    if state == "SUPPRESS":
        var suppress_target: Vector3 = main.call("_get_bot_squad_engagement_target", self)
        var suppress_distance := global_position.distance_to(suppress_target)
        if suppress_distance > OPTIMAL_RANGE + 2.0:
            current_goal = suppress_target
            _ensure_route(current_goal)
        else:
            current_goal = global_position
            route.clear()
            route_index = 0
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
    keep_current_defend_goal = keep_current_defend_goal and main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), current_goal)

    if not keep_current_defend_goal:
        var tactical_cover = main.call("_select_bot_site_cover", self, site_position, target.global_position, role)
        if tactical_cover is Vector3 and tactical_cover != Vector3.ZERO:
            current_goal = tactical_cover
        else:
            current_goal = site_position
        route.clear()
        route_index = 0

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
    if not goal_changed and route_replan_timer > 0.0:
        return

    route = main.call("_find_navigation_route", global_position, goal)
    route_index = 0
    route_goal = goal
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
        if distance <= OPTIMAL_RANGE and distance >= MIN_COMBAT_RANGE:
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
        if distance < MIN_COMBAT_RANGE:
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
            # Long-range pursuit must use the navigation graph rather than
            # steering directly through map geometry.
            _ensure_route(target.global_position)
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
        route_index += 1
        if route_index >= route.size():
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            return
        waypoint = route[route_index]
        waypoint.y = global_position.y
        offset = waypoint - global_position

    var direction := offset.normalized()
    var speed := SPRINT_SPEED if state == "DEFUSE" else MOVE_SPEED
    velocity.x = move_toward(velocity.x, direction.x * speed, 12.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 12.0 * delta)
    look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)

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

    var origin := global_position + Vector3(0, 1.0, 0)
    var aim := target.global_position + Vector3(0, 0.5, 0)
    if randf() > ACCURACY:
        aim += Vector3(randf_range(-0.45, 0.45), randf_range(-0.30, 0.30), randf_range(-0.45, 0.45))

    var query := PhysicsRayQueryParameters3D.create(origin, aim)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider == target:
        main.call("_apply_damage", DAMAGE)

    if burst_remaining <= 0:
        burst_pause = BURST_PAUSE

func take_damage(amount: int) -> void:
    if dead:
        return
    health = maxi(0, health - amount)
    recently_hit_timer = RECENT_HIT_REACTION_TIME
    combat_reposition_timer = 0.0
    combat_reposition_goal = Vector3.ZERO
    route.clear()
    route_index = 0
    route_goal = Vector3.ZERO
    route_replan_timer = 0.0
    if health == 0:
        _die()

func reset_target() -> void:
    health = max_health
    dead = false
    visible = true
    collision_layer = 1
    collision_mask = 1
    if collision_shape:
        collision_shape.disabled = false
    route.clear()
    route_index = 0
    route_goal = Vector3.ZERO
    route_replan_timer = 0.0
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
    combat_reposition_timer = 0.0
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
    dead = true
    visible = false
    if collision_shape:
        collision_shape.disabled = true
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    eliminated.emit(self)
