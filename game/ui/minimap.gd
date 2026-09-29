extends Control
## Lightweight north-up tactical minimap. Render-only; it never exposes enemy positions.

const WORLD_HALF_EXTENT := 18.0
const MAP_PADDING := 11.0

var player_position := Vector3.ZERO
var player_yaw := 0.0
var bomb_position := Vector3.ZERO
var bomb_visible := false
var planted_site := ""

func _ready() -> void:
	custom_minimum_size = Vector2(156.0, 156.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	var game_root := get_tree().current_scene
	if game_root == null:
		return
	var player_value = game_root.get("player")
	if not is_instance_valid(player_value):
		return
	var objective_state := str(game_root.get("objective_state"))
	var show_bomb := objective_state == "DROPPED" or objective_state == "PLANTED"
	var objective_position: Vector3 = game_root.get("dropped_bomb_position")
	if objective_state == "PLANTED":
		var site := str(game_root.get("planted_site"))
		objective_position = Vector3(-10.0, 0.0, -7.0) if site == "A" else Vector3(10.0, 0.0, 7.0)
	set_match_state(
		player_value.global_position,
		player_value.rotation.y,
		objective_position,
		show_bomb,
		str(game_root.get("planted_site"))
	)

func set_match_state(
	position_value: Vector3,
	yaw_value: float,
	bomb_position_value: Vector3,
	show_bomb: bool,
	planted_site_value: String
) -> void:
	player_position = position_value
	player_yaw = yaw_value
	bomb_position = bomb_position_value
	bomb_visible = show_bomb
	planted_site = planted_site_value
	queue_redraw()

func _map_point(world_position: Vector3) -> Vector2:
	var usable := size - Vector2.ONE * MAP_PADDING * 2.0
	return Vector2(
		MAP_PADDING + clampf((world_position.x + WORLD_HALF_EXTENT) / (WORLD_HALF_EXTENT * 2.0), 0.0, 1.0) * usable.x,
		MAP_PADDING + clampf((world_position.z + WORLD_HALF_EXTENT) / (WORLD_HALF_EXTENT * 2.0), 0.0, 1.0) * usable.y
	)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.012, 0.025, 0.04, 0.90), true)
	draw_rect(bounds, Color(0.12, 0.68, 0.80, 0.92), false, 2.0)

	var map_rect := Rect2(
		Vector2(MAP_PADDING, MAP_PADDING),
		size - Vector2.ONE * MAP_PADDING * 2.0
	)
	draw_rect(map_rect, Color(0.055, 0.09, 0.12, 0.92), true)
	# Perimeter walls and restrained grid lines establish a north-up map frame.
	draw_rect(map_rect, Color(0.30, 0.42, 0.48, 0.95), false, 1.5)
	for fraction in [0.25, 0.5, 0.75]:
		var gx := map_rect.position.x + map_rect.size.x * fraction
		var gy := map_rect.position.y + map_rect.size.y * fraction
		draw_line(Vector2(gx, map_rect.position.y), Vector2(gx, map_rect.end.y), Color(0.18, 0.27, 0.32, 0.50), 1.0)
		draw_line(Vector2(map_rect.position.x, gy), Vector2(map_rect.end.x, gy), Color(0.18, 0.27, 0.32, 0.50), 1.0)

	# Site markers match the amber/cyan world-space objective palette.
	_draw_site(Vector3(-10.0, 0.0, -7.0), "A", Color(1.0, 0.58, 0.18))
	_draw_site(Vector3(10.0, 0.0, 7.0), "B", Color(0.12, 0.78, 0.96))

	if bomb_visible:
		var bomb_point := _map_point(bomb_position)
		draw_circle(bomb_point, 5.5, Color(1.0, 0.22, 0.10, 0.98))
		draw_arc(bomb_point, 8.0, 0.0, TAU, 24, Color(1.0, 0.68, 0.25, 0.95), 1.5, true)
		draw_string(get_theme_default_font(), bomb_point + Vector2(7.0, -5.0), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.78, 0.55))

	# Directional player arrow; no enemy markers are shown through walls.
	var player_point := _map_point(player_position)
	var forward := Vector2(-sin(player_yaw), -cos(player_yaw))
	var side := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([
		player_point + forward * 7.0,
		player_point - forward * 5.0 + side * 4.8,
		player_point - forward * 5.0 - side * 4.8
	])
	draw_colored_polygon(arrow, Color(0.35, 0.94, 1.0, 1.0))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0.02, 0.08, 0.12, 1.0), 1.2, true)

	draw_string(get_theme_default_font(), Vector2(MAP_PADDING + 3.0, size.y - 3.0), "N  ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.84, 0.90, 0.92))

func _draw_site(world_position: Vector3, label: String, tint: Color) -> void:
	var point := _map_point(world_position)
	draw_circle(point, 5.0, tint.darkened(0.38))
	draw_arc(point, 7.0, 0.0, TAU, 24, tint, 1.5, true)
	draw_string(get_theme_default_font(), point + Vector2(8.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
