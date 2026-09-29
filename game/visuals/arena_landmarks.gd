extends Node3D

# Small, static wayfinding panels add readable landmarks to the center lane.
# They are render-only: no collision shapes, lights, shadows, or navigation data.

var accent_materials: Array[StandardMaterial3D] = []
var pulse_time := 0.0


func _process(delta: float) -> void:
    # Slow emissive breathing keeps the wall wayfinding panels alive without
    # adding lights, particles, or any gameplay-side work.
    pulse_time = fmod(pulse_time + delta, TAU)
    for index in accent_materials.size():
        var material := accent_materials[index]
        if is_instance_valid(material):
            var phase := pulse_time * 1.25 + float(index) * 1.7
            material.emission_energy_multiplier = 0.62 + (sin(phase) + 1.0) * 0.22


func _ready() -> void:
    _build_wall_marker(
        "MidControlMarker",
        Vector3(-17.40, 2.45, 0.0),
        -PI / 2.0,
        "MID CONTROL",
        "SECTOR 02  /  CENTRAL ROUTE",
        Color(0.06, 0.66, 0.88)
    )
    _build_wall_marker(
        "CrossLaneMarker",
        Vector3(17.40, 2.45, 0.0),
        PI / 2.0,
        "CROSS-LANE",
        "SECTOR 03  /  TRANSIT",
        Color(0.98, 0.57, 0.19)
    )

func _build_wall_marker(
    marker_name: String,
    marker_position: Vector3,
    facing_y: float,
    title_text: String,
    subtitle_text: String,
    accent_color: Color
) -> void:
    var marker := Node3D.new()
    marker.name = marker_name
    marker.position = marker_position
    marker.rotation.y = facing_y
    add_child(marker)

    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = Color(0.018, 0.032, 0.048)
    panel_material.metallic = 0.42
    panel_material.roughness = 0.62

    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.10, 0.14, 0.18)
    frame_material.metallic = 0.55
    frame_material.roughness = 0.48

    var accent_material := StandardMaterial3D.new()
    accent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    accent_material.albedo_color = accent_color
    accent_material.emission_enabled = true
    accent_material.emission = accent_color * 0.38
    accent_material.emission_energy_multiplier = 0.85
    accent_materials.append(accent_material)

    _add_box(marker, Vector3.ZERO, Vector3(4.6, 1.15, 0.12), frame_material)
    _add_box(marker, Vector3(0.0, 0.0, -0.075), Vector3(4.42, 0.98, 0.035), panel_material)
    _add_box(marker, Vector3(-2.08, 0.0, -0.10), Vector3(0.07, 0.84, 0.035), accent_material)
    _add_box(marker, Vector3(0.0, 0.49, -0.10), Vector3(4.35, 0.045, 0.035), accent_material)

    var title := Label3D.new()
    title.name = "Title"
    title.text = title_text
    title.position = Vector3(0.0, 0.13, -0.12)
    title.font_size = 56
    title.pixel_size = 0.010
    title.modulate = accent_color
    title.outline_size = 8
    title.outline_modulate = Color(0.005, 0.012, 0.02, 0.98)
    title.shaded = false
    marker.add_child(title)

    var subtitle := Label3D.new()
    subtitle.name = "Subtitle"
    subtitle.text = subtitle_text
    subtitle.position = Vector3(0.0, -0.24, -0.12)
    subtitle.font_size = 24
    subtitle.pixel_size = 0.010
    subtitle.modulate = Color(0.72, 0.82, 0.88)
    subtitle.outline_size = 5
    subtitle.outline_modulate = Color(0.005, 0.012, 0.02, 0.98)
    subtitle.shaded = false
    marker.add_child(subtitle)

func _add_box(parent: Node3D, local_position: Vector3, box_size: Vector3, material: Material) -> void:
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = box_size
    mesh_instance.mesh = box
    mesh_instance.position = local_position
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh_instance)
