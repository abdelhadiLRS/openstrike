extends Control

## Lightweight north-up tactical map. It shows static map geometry and objectives,
## never hidden enemy positions, so it does not leak opponent locations.
var game_root: Node3D
const MAP_HALF_EXTENT := 18.0
const MAP_PADDING := 12.0
const MAP_BACKGROUND := Color(0.018, 0.035, 0.052, 0.88)
const MAP_BORDER := Color(0.20, 0.66, 0.76, 0.92)
const GRID_COLOR := Color(0.20, 0.32, 0.38, 0.34)

func setup(root: Node3D) -> void:
    game_root = root
    queue_redraw()

func _ready() -> void:
    name = "TacticalMinimap"
    custom_minimum_size = Vector2(196.0, 196.0)
    size = custom_minimum_size
    set_anchors_preset(Control.PRESET_TOP_RIGHT)
    position = Vector2(-214.0, 18.0)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 20

func _process(_delta: float) -> void:
    if is_instance_valid(game_root):
        queue_redraw()

func _draw() -> void:
    var bounds := Rect2(Vector2.ZERO, size)
    draw_rect(bounds, MAP_BACKGROUND, true)
    draw_rect(bounds, MAP_BORDER, false, 2.0)

    var center := size * 0.5
    var scale_factor := (minf(size.x, size.y) - MAP_PADDING * 2.0) / (MAP_HALF_EXTENT * 2.0)
    for grid_coord in [-12.0, -6.0, 0.0, 6.0, 12.0]:
        var gx := center.x + grid_coord * scale_factor
        var gy := center.y + grid_coord * scale_factor
        draw_line(Vector2(gx, MAP_PADDING), Vector2(gx, size.y - MAP_PADDING), GRID_COLOR, 1.0)
        draw_line(Vector2(MAP_PADDING, gy), Vector2(size.x - MAP_PADDING, gy), GRID_COLOR, 1.0)

    # Map perimeter and the existing hard-cover layout are only drawn as
    # navigation references; no enemy/player positions are exposed here.
    _draw_map_rect(center, scale_factor, Vector2(0.0, -18.0), Vector2(36.0, 1.0), Color(0.35, 0.43, 0.48, 0.9))
    _draw_map_rect(center, scale_factor, Vector2(0.0, 18.0), Vector2(36.0, 1.0), Color(0.35, 0.43, 0.48, 0.9))
    _draw_map_rect(center, scale_factor, Vector2(-18.0, 0.0), Vector2(1.0, 36.0), Color(0.35, 0.43, 0.48, 0.9))
    _draw_map_rect(center, scale_factor, Vector2(18.0, 0.0), Vector2(1.0, 36.0), Color(0.35, 0.43, 0.48, 0.9))

    var cover_specs := [
        [Vector2(-7.0, -5.0), Vector2(3.0, 2.0)],
        [Vector2(6.0, -2.0), Vector2(3.0, 2.0)],
        [Vector2(-3.0, 7.0), Vector2(3.0, 2.0)],
        [Vector2(10.0, 9.0), Vector2(3.0, 2.0)],
        [Vector2(-12.0, -7.0), Vector2(2.8, 1.2)],
        [Vector2(-2.0, -8.0), Vector2(3.4, 1.2)],
        [Vector2(7.0, -7.0), Vector2(2.6, 1.2)],
        [Vector2(-9.0, 4.0), Vector2(2.4, 1.4)],
        [Vector2(2.0, 5.0), Vector2(3.2, 1.2)],
        [Vector2(11.0, 4.0), Vector2(2.4, 1.4)]
    ]
    for spec in cover_specs:
        _draw_map_rect(center, scale_factor, spec[0], spec[1], Color(0.22, 0.32, 0.38, 0.92))

    _draw_objective(center, scale_factor, Vector2(-10.0, -7.0), "A", Color(0.12, 0.78, 0.98))
    _draw_objective(center, scale_factor, Vector2(10.0, 7.0), "B", Color(1.0, 0.58, 0.20))

    if is_instance_valid(game_root):
        var session = game_root.get("network_session")
        if is_instance_valid(session):
            var network_players = session.get("network_players")
            if network_players is Dictionary:
                for peer_value in network_players.keys():
                    var ally = network_players.get(peer_value)
                    if not is_instance_valid(ally) or bool(ally.get("dead")):
                        continue
                    if str(ally.get("team")) != "BLUE":
                        continue
                    var ally_position: Vector3 = ally.global_position
                    var ally_point := _map_point(center, scale_factor, Vector2(ally_position.x, ally_position.z))
                    var ally_yaw := float(ally.rotation.y)
                    var ally_forward := Vector2(-sin(ally_yaw), cos(ally_yaw))
                    var ally_side := Vector2(-ally_forward.y, ally_forward.x)
                    var ally_tip := ally_point + ally_forward * 7.0
                    var ally_left := ally_point - ally_forward * 3.0 + ally_side * 3.5
                    var ally_right := ally_point - ally_forward * 3.0 - ally_side * 3.5
                    # A small heading arrow distinguishes ally orientation without
                    # exposing enemy positions or adding any gameplay information.
                    draw_colored_polygon(PackedVector2Array([ally_tip, ally_left, ally_right]), Color(0.30, 0.72, 1.0, 0.98))
                    draw_circle(ally_point, 2.4, Color(0.72, 0.90, 1.0, 1.0))
                    draw_arc(ally_point, 5.0, 0.0, TAU, 16, Color(0.55, 0.82, 1.0, 0.8), 1.0, true)

        var objective_state := str(game_root.get("objective_state"))
        var bomb_position := Vector3.ZERO
        var show_bomb := false
        if objective_state == "DROPPED":
            bomb_position = game_root.get("dropped_bomb_position")
            show_bomb = true
        elif objective_state == "PLANTED":
            var bomb_node = game_root.get("bomb_visual")
            if is_instance_valid(bomb_node) and bomb_node is Node3D:
                bomb_position = bomb_node.global_position
                show_bomb = true
        if show_bomb:
            var bomb_point := _map_point(center, scale_factor, Vector2(bomb_position.x, bomb_position.z))
            draw_circle(bomb_point, 7.0, Color(1.0, 0.16, 0.10, 0.20))
            draw_arc(bomb_point, 7.0, 0.0, TAU, 20, Color(1.0, 0.22, 0.14, 1.0), 1.8, true)
            draw_colored_polygon(PackedVector2Array([
                bomb_point + Vector2(0.0, -4.0),
                bomb_point + Vector2(4.0, 0.0),
                bomb_point + Vector2(0.0, 4.0),
                bomb_point + Vector2(-4.0, 0.0)
            ]), Color(1.0, 0.30, 0.18, 1.0))

        var player_node = game_root.get("player")
        if is_instance_valid(player_node) and player_node is Node3D:
            var player_position: Vector3 = player_node.global_position
            var player_point := _map_point(center, scale_factor, Vector2(player_position.x, player_position.z))
            var yaw := float(player_node.rotation.y)
            var forward := Vector2(-sin(yaw), cos(yaw))
            var side := Vector2(-forward.y, forward.x)
            # A faint facing wedge gives immediate orientation at a glance;
            # the brighter arrow remains the precise player heading marker.
            var cone_tip := player_point + forward * 18.0
            var cone_left := player_point + forward * 2.0 + side * 9.0
            var cone_right := player_point + forward * 2.0 - side * 9.0
            draw_colored_polygon(PackedVector2Array([cone_tip, cone_left, cone_right]), Color(0.25, 0.88, 0.68, 0.12))
            var tip := player_point + forward * 7.0
            var left := player_point - forward * 4.0 + side * 4.0
            var right := player_point - forward * 4.0 - side * 4.0
            draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.36, 0.96, 0.74, 1.0))
            draw_circle(player_point, 4.0, Color(0.92, 1.0, 0.96, 1.0))
            draw_arc(player_point, 6.0, 0.0, TAU, 20, Color(0.36, 0.96, 0.74, 0.62), 1.0, true)

    # Cardinal cues and a north tick make the north-up map easier to read.
    draw_string(ThemeDB.fallback_font, Vector2(center.x - 4.0, 12.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.78, 0.90, 0.95, 0.96))
    draw_line(Vector2(center.x, 18.0), Vector2(center.x, 25.0), MAP_BORDER, 1.5)
    draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y - 8.0), "TACTICAL MAP  /  NORTH UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.78, 0.83, 0.95))

func _map_point(center: Vector2, scale_factor: float, world_xz: Vector2) -> Vector2:
    return center + world_xz * scale_factor

func _draw_map_rect(center: Vector2, scale_factor: float, world_center: Vector2, world_size: Vector2, color: Color) -> void:
    var screen_center := _map_point(center, scale_factor, world_center)
    var screen_size := world_size * scale_factor
    draw_rect(Rect2(screen_center - screen_size * 0.5, screen_size), color, true)

func _draw_objective(center: Vector2, scale_factor: float, world_position: Vector2, label: String, color: Color) -> void:
    var point := _map_point(center, scale_factor, world_position)
    var planted_here := false
    if is_instance_valid(game_root):
        planted_here = str(game_root.get("objective_state")) == "PLANTED" and str(game_root.get("planted_site")) == label

    if planted_here:
        var pulse := (sin(float(Time.get_ticks_msec()) * 0.006) + 1.0) * 0.5
        var alert_color := Color(1.0, 0.20, 0.13, 0.98)
        draw_circle(point, 10.0 + pulse * 3.0, Color(1.0, 0.12, 0.08, 0.12 + pulse * 0.10))
        draw_arc(point, 10.0 + pulse * 3.0, 0.0, TAU, 28, alert_color, 2.0, true)
        draw_colored_polygon(PackedVector2Array([
            point + Vector2(0.0, -4.0),
            point + Vector2(4.0, 0.0),
            point + Vector2(0.0, 4.0),
            point + Vector2(-4.0, 0.0)
        ]), alert_color)
        draw_string(ThemeDB.fallback_font, point + Vector2(11.0, 4.0), label + "  PLANTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, alert_color)
        return

    draw_circle(point, 7.0, Color(color.r, color.g, color.b, 0.18))
    draw_arc(point, 7.0, 0.0, TAU, 24, color, 1.6, true)
    draw_circle(point, 2.4, color)
    draw_string(ThemeDB.fallback_font, point + Vector2(9.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
