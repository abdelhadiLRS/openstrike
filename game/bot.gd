extends CharacterBody3D

signal eliminated(bot)

const GRAVITY := 14.0
const MOVE_SPEED := 3.4
const SPRINT_SPEED := 4.2
const DETECTION_RANGE := 26.0
const FIRE_RANGE := 22.0
const FIRE_DELAY := 0.34
const DAMAGE := 12
const WAYPOINT_REACHED := 1.1
const SITE_RADIUS := 2.8

var team := "RED"
var max_health := 100
var health := 100
var dead := false
var fire_cooldown := 0.0
var target: Node3D
var main: Node3D
var state := "DEFEND"
var route := []
var route_index := 0
var current_goal := Vector3.ZERO
var last_state := "DEFEND"
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
    target = main.get("player")
    if not is_instance_valid(target):
        return

    _update_state()
    if state != last_state:
        route.clear()
        route_index = 0
        last_state = state
    _update_goal()
    _move_toward_goal(delta)

    if state == "ATTACK" and _has_line_of_sight():
        _fire()

    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    move_and_slide()

func _update_state() -> void:
    var objective_state := str(main.get("objective_state"))
    if objective_state == "PLANTED":
        state = "DEFUSE"
        return

    var distance := global_position.distance_to(target.global_position)
    if distance <= DETECTION_RANGE:
        state = "ATTACK"
    else:
        state = "DEFEND"

func _update_goal() -> void:
    var objective_state := str(main.get("objective_state"))

    if state == "DEFUSE" and objective_state == "PLANTED":
        var planted_site := str(main.get("planted_site"))
        current_goal = main.get("bomb_site_a") if planted_site == "A" else main.get("bomb_site_b")
        _ensure_route(current_goal)
        return

    if state == "ATTACK":
        current_goal = target.global_position
        route.clear()
        route_index = 0
        return

    var defend_site := "A" if int(get_index()) % 2 == 0 else "B"
    current_goal = main.get("bomb_site_a") if defend_site == "A" else main.get("bomb_site_b")
    _ensure_route(current_goal)

func _ensure_route(goal: Vector3) -> void:
    if route.size() > 0 and route_index < route.size():
        return

    var points: Array = main.get("navigation_points")
    route.clear()
    route_index = 0

    var nearest := -1
    var nearest_distance := INF
    for i in points.size():
        var distance := points[i].distance_to(global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = i

    if nearest >= 0:
        route.append(points[nearest])

    var goal_nearest := -1
    var goal_distance := INF
    for i in points.size():
        var distance := points[i].distance_to(goal)
        if distance < goal_distance:
            goal_distance = distance
            goal_nearest = i

    if goal_nearest >= 0 and goal_nearest != nearest:
        route.append(points[goal_nearest])

    route.append(goal)

func _move_toward_goal(delta: float) -> void:
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
    if fire_cooldown > 0.0:
        return
    fire_cooldown = FIRE_DELAY

    var origin := global_position + Vector3(0, 1.0, 0)
    var target_position := target.global_position + Vector3(0, 0.5, 0)
    var query := PhysicsRayQueryParameters3D.create(origin, target_position)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider == target:
        main.call("_apply_damage", DAMAGE)

func take_damage(amount: int) -> void:
    if dead:
        return
    health = maxi(0, health - amount)
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
    fire_cooldown = 0.0

func _die() -> void:
    dead = true
    visible = false
    if collision_shape:
        collision_shape.disabled = true
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    eliminated.emit(self)
