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
    burst_pause = maxf(0.0, burst_pause - delta)
    strafe_time = maxf(0.0, strafe_time - delta)
    if strafe_time <= 0.0:
        strafe_time = STRAFE_INTERVAL
        strafe_sign *= -1.0
    target = main.get("player")
    if not is_instance_valid(target):
        return

    _update_state()
    if state != last_state:
        route.clear()
        route_index = 0
        if state != "BOMB_COVER":
            bomb_cover_goal = Vector3.ZERO
            bomb_cover_site = ""
            bomb_cover_revision = -1
        last_state = state
    _update_goal()
    _move_toward_goal(delta)

    if (state == "ATTACK" or state == "PEEK" or state == "BOMB_COVER") and _has_line_of_sight():
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

    if has_los and distance <= PUSH_DISTANCE:
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
        if bomb_cover_site != planted_site or bomb_cover_goal == Vector3.ZERO or bomb_cover_revision != defense_revision:
            var selected_cover = main.call("_select_bot_bomb_cover", site_position, target.global_position, self)
            bomb_cover_goal = selected_cover if selected_cover is Vector3 else Vector3.ZERO
            bomb_cover_site = planted_site
            bomb_cover_revision = defense_revision
            route.clear()
            route_index = 0
        current_goal = bomb_cover_goal if bomb_cover_goal != Vector3.ZERO else site_position
        _ensure_route(current_goal)
        return

    if state == "DEFUSE" and objective_state == "PLANTED":
        var planted_site := str(main.get("planted_site"))
        current_goal = main.get("bomb_site_a") if planted_site == "A" else main.get("bomb_site_b")
        _ensure_route(current_goal)
        return

    if state == "ATTACK":
        var distance := global_position.distance_to(target.global_position)
        if distance > OPTIMAL_RANGE:
            current_goal = target.global_position
        else:
            current_goal = global_position
        route.clear()
        route_index = 0
        return

    if state == "COVER" or state == "PEEK":
        if combat_intent == "RETREAT":
            var retreat_cover = main.call("_select_bot_combat_cover", self, target.global_position, 12.0)
            if retreat_cover is Vector3 and retreat_cover != Vector3.ZERO:
                current_goal = retreat_cover
                cover_index = -1
                _ensure_route(current_goal)
                return
        _select_cover_point()
        if cover_index >= 0:
            var cover_data: Dictionary = main.get("cover_points")[cover_index]
            current_goal = cover_data["cover"] if state == "COVER" else cover_data["peek"]
            _ensure_route(current_goal)
        return

    var defend_site := "A" if role == "DEFENDER_A" else "B"
    if role == "ROAMER":
        defend_site = "B" if int(Time.get_ticks_msec() / 5000.0) % 2 == 0 else "A"
    var site_position: Vector3 = main.get("bomb_site_a") if defend_site == "A" else main.get("bomb_site_b")
    var tactical_cover = main.call("_select_bot_site_cover", site_position, target.global_position, role)
    if tactical_cover is Vector3 and tactical_cover != Vector3.ZERO:
        current_goal = tactical_cover
    else:
        current_goal = site_position
    _ensure_route(current_goal)

func _select_cover_point() -> void:
    var points: Array = main.get("cover_points")
    if points.is_empty():
        cover_index = -1
        return
    if cover_index >= 0 and cover_index < points.size():
        var current: Dictionary = points[cover_index]
        var current_cover: Vector3 = current["cover"]
        if global_position.distance_to(current_cover) <= COVER_REACHED * 2.5:
            return

    var best := -1
    var best_score := INF
    for i in points.size():
        var data: Dictionary = points[i]
        var cover_position: Vector3 = data["cover"]
        var distance := global_position.distance_to(cover_position)
        if distance > 18.0:
            continue
        var player_distance := cover_position.distance_to(target.global_position)
        if player_distance < 5.0:
            continue
        if not main.call("_has_obstacle_between", target.global_position + Vector3(0, 1.0, 0), cover_position):
            continue
        var peek_position: Vector3 = data["peek"]
        if main.call("_has_obstacle_between", peek_position, target.global_position + Vector3(0, 1.0, 0)):
            continue
        var score := distance + absf(player_distance - OPTIMAL_RANGE) * 0.25
        if score < best_score:
            best_score = score
            best = i
    cover_index = best

func _ensure_route(goal: Vector3) -> void:
    if route.size() > 0 and route_index < route.size():
        return

    route = main.call("_find_navigation_route", global_position, goal)
    route_index = 0

func _move_toward_goal(delta: float) -> void:
    if state == "BOMB_COVER" and str(main.get("objective_state")) == "PLANTED":
        var bomb_cover_offset := current_goal - global_position
        bomb_cover_offset.y = 0.0
        if bomb_cover_offset.length() <= COVER_REACHED:
            velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
            var bomb_look := (target.global_position - global_position).normalized()
            look_at(global_position + Vector3(bomb_look.x, 0.0, bomb_look.z), Vector3.UP)
            if _has_line_of_sight():
                var side := Vector3(-bomb_look.z, 0.0, bomb_look.x) * strafe_sign
                velocity.x = move_toward(velocity.x, side.x * 0.8, 6.0 * delta)
                velocity.z = move_toward(velocity.z, side.z * 0.8, 6.0 * delta)
            return

    if state == "ATTACK":
        var distance := global_position.distance_to(target.global_position)
        if distance <= OPTIMAL_RANGE and distance >= MIN_COMBAT_RANGE:
            var to_target := (target.global_position - global_position).normalized()
            var strafe := Vector3(-to_target.z, 0.0, to_target.x) * strafe_sign
            velocity.x = move_toward(velocity.x, strafe.x * 1.5, 10.0 * delta)
            velocity.z = move_toward(velocity.z, strafe.z * 1.5, 10.0 * delta)
            look_at(global_position + Vector3(to_target.x, 0.0, to_target.z), Vector3.UP)
            return
        if distance < MIN_COMBAT_RANGE:
            var away := (global_position - target.global_position).normalized()
            velocity.x = move_toward(velocity.x, away.x * MOVE_SPEED, 12.0 * delta)
            velocity.z = move_toward(velocity.z, away.z * MOVE_SPEED, 12.0 * delta)
            look_at(global_position + Vector3(-away.x, 0.0, -away.z), Vector3.UP)
            return
        if distance > OPTIMAL_RANGE:
            var chase := (target.global_position - global_position).normalized()
            velocity.x = move_toward(velocity.x, chase.x * MOVE_SPEED, 12.0 * delta)
            velocity.z = move_toward(velocity.z, chase.z * MOVE_SPEED, 12.0 * delta)
            look_at(global_position + Vector3(chase.x, 0.0, chase.z), Vector3.UP)
            return

    if state == "COVER" or state == "PEEK":
        if cover_index < 0:
            return
        var cover_data: Dictionary = main.get("cover_points")[cover_index]
        var destination: Vector3 = cover_data["cover"] if state == "COVER" else cover_data["peek"]
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
        return

    if route_index >= route.size():
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
    route.clear()
    route_index = 0
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
    last_state = "DEFEND"
    current_goal = Vector3.ZERO
    cover_index = -1
    bomb_cover_goal = Vector3.ZERO
    bomb_cover_site = ""
    bomb_cover_revision = -1
    peek_timer = 0.0
    peek_hold_timer = 0.0
    combat_intent = "HOLD"
    combat_decision_timer = 0.0
    recently_hit_timer = 0.0
    combat_reposition_timer = 0.0
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
