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
        var player_node = game_root.get("player")
        if is_instance_valid(player_node) and player_node is Node3D:
            var player_position: Vector3 = player_node.global_position
            var player_point := _map_point(center, scale_factor, Vector2(player_position.x, player_position.z))
            var yaw := float(player_node.rotation.y)
            var forward := Vector2(-sin(yaw), cos(yaw))
            var side := Vector2(-forward.y, forward.x)
            var tip := player_point + forward * 7.0
            var left := player_point - forward * 4.0 + side * 4.0
            var right := player_point - forward * 4.0 - side * 4.0
            draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.36, 0.96, 0.74, 1.0))
            draw_circle(player_point, 3.0, Color(0.92, 1.0, 0.96, 1.0))

    draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y - 8.0), "TACTICAL MAP  /  N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.62, 0.78, 0.83, 0.95))

func _map_point(center: Vector2, scale_factor: float, world_xz: Vector2) -> Vector2:
    return center + world_xz * scale_factor

func _draw_map_rect(center: Vector2, scale_factor: float, world_center: Vector2, world_size: Vector2, color: Color) -> void:
    var screen_center := _map_point(center, scale_factor, world_center)
    var screen_size := world_size * scale_factor
    draw_rect(Rect2(screen_center - screen_size * 0.5, screen_size), color, true)

func _draw_objective(center: Vector2, scale_factor: float, world_position: Vector2, label: String, color: Color) -> void:
    var point := _map_point(center, scale_factor, world_position)
    draw_circle(point, 7.0, Color(color.r, color.g, color.b, 0.18))
    draw_arc(point, 7.0, 0.0, TAU, 24, color, 1.6, true)
    draw_circle(point, 2.4, color)
    draw_string(ThemeDB.fallback_font, point + Vector2(9.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
