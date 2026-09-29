extends Node3D

## Small industrial floor service plates for the four quiet arena corners.
## Everything is render-only: no collision, shadows, lights, or navigation data.

var status_materials: Array[StandardMaterial3D] = []
var status_phases: Array[float] = []
var pulse_time := 0.0

const PLATE_POSITIONS := [
    Vector3(-13.2, 0.013, -13.2),
    Vector3(13.2, 0.013, -13.2),
    Vector3(-13.2, 0.013, 13.2),
    Vector3(13.2, 0.013, 13.2)
]

func _process(delta: float) -> void:
    pulse_time = fmod(pulse_time + delta, TAU)
    for index in status_materials.size():
        var material := status_materials[index]
        if not is_instance_valid(material):
            continue
        var pulse := (sin(pulse_time * 2.0 + status_phases[index]) + 1.0) * 0.5
        material.emission_energy_multiplier = 0.35 + pulse * 0.8


func _ready() -> void:
    _build_corner_plates()
    _build_wall_service_runs()
    _build_wall_beacons()


func _build_corner_plates() -> void:
    var base_material := StandardMaterial3D.new()
    base_material.albedo_color = Color(0.055, 0.075, 0.09)
    base_material.metallic = 0.58
    base_material.roughness = 0.62

    var inset_material := StandardMaterial3D.new()
    inset_material.albedo_color = Color(0.12, 0.15, 0.17)
    inset_material.metallic = 0.28
    inset_material.roughness = 0.82

    var stripe_material := StandardMaterial3D.new()
    stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    stripe_material.albedo_color = Color(0.95, 0.48, 0.12, 0.88)
    stripe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var label_material := StandardMaterial3D.new()
    label_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    label_material.albedo_color = Color(0.48, 0.66, 0.72, 0.82)
    label_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    for index in PLATE_POSITIONS.size():
        var plate := Node3D.new()
        plate.name = "CornerServicePlate%02d" % (index + 1)
        plate.position = PLATE_POSITIONS[index]
        add_child(plate)

        _add_box(plate, Vector3.ZERO, Vector3(2.65, 0.025, 1.55), base_material)
        _add_box(plate, Vector3(0.0, 0.014, 0.0), Vector3(2.48, 0.012, 1.38), inset_material)

        # Short diagonal safety bars sit inside the inset and stay clear of
        # the central movement lanes.
        for stripe_index in range(7):
            var stripe_x := -0.82 + float(stripe_index) * 0.27
            var stripe := _add_box(
                plate,
                Vector3(stripe_x, 0.024, -0.18),
                Vector3(0.10, 0.008, 0.72),
                stripe_material
            )
            stripe.rotation.y = -0.42 if index % 2 == 0 else 0.42

        var label := Label3D.new()
        label.name = "ServiceLabel"
        label.text = "SERVICE  /  %02d" % (index + 1)
        label.position = Vector3(0.0, 0.035, 0.43)
        label.rotation_degrees.x = -90.0
        label.font_size = 26
        label.pixel_size = 0.008
        label.modulate = Color(0.62, 0.76, 0.80, 0.72)
        label.outline_size = 4
        label.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
        label.shaded = false
        plate.add_child(label)

        # Tiny paired status LEDs add a subtle active-facility cue to each plate.
        _add_status_led(plate, Vector3(-1.12, 0.035, 0.48), Color(0.06, 0.62, 0.88), float(index) * 0.8)
        _add_status_led(plate, Vector3(1.12, 0.035, 0.48), Color(0.98, 0.48, 0.14), float(index) * 0.8 + 1.3)


func _add_box(parent: Node3D, local_position: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = box_size
    mesh_instance.mesh = box
    mesh_instance.position = local_position
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh_instance)
    return mesh_instance


func _add_status_led(parent: Node3D, local_position: Vector3, color: Color, phase: float) -> void:
    var led := MeshInstance3D.new()
    var led_mesh := BoxMesh.new()
    led_mesh.size = Vector3(0.12, 0.025, 0.07)
    led.mesh = led_mesh
    led.position = local_position
    led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var led_material := StandardMaterial3D.new()
    led_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    led_material.albedo_color = color
    led_material.emission_enabled = true
    led_material.emission = color * 0.65
    led_material.emission_energy_multiplier = 0.6
    led.material_override = led_material
    status_materials.append(led_material)
    status_phases.append(phase)
    parent.add_child(led)


func _build_wall_service_runs() -> void:
    # Short elevated cable trays break up the long perimeter walls. These
    # decorative meshes are shadow-free and do not affect collision/navigation.
    var tray_material := StandardMaterial3D.new()
    tray_material.albedo_color = Color(0.075, 0.105, 0.125)
    tray_material.metallic = 0.62
    tray_material.roughness = 0.58

    var rail_material := StandardMaterial3D.new()
    rail_material.albedo_color = Color(0.22, 0.29, 0.32)
    rail_material.metallic = 0.72
    rail_material.roughness = 0.46

    var status_material := StandardMaterial3D.new()
    status_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    status_material.albedo_color = Color(0.08, 0.62, 0.82)
    status_material.emission_enabled = true
    status_material.emission = Color(0.08, 0.62, 0.82) * 0.32
    status_material.emission_energy_multiplier = 0.7
    status_materials.append(status_material)
    status_phases.append(0.6)

    for side in [-1.0, 1.0]:
        for segment in range(3):
            var z := -9.0 + float(segment) * 9.0
            var center := Vector3(side * 16.85, 2.85, z)
            _add_box(self, center, Vector3(0.18, 0.22, 6.2), tray_material)
            _add_box(self, center + Vector3(side * 0.11, 0.0, 0.0), Vector3(0.055, 0.28, 6.35), rail_material)
            for clamp_index in range(4):
                var clamp_z := z - 2.5 + float(clamp_index) * 1.65
                _add_box(self, Vector3(side * 16.70, 2.85, clamp_z), Vector3(0.20, 0.34, 0.10), rail_material)
            _add_box(self, Vector3(side * 16.68, 2.69, z), Vector3(0.045, 0.035, 1.05), status_material)


func _build_wall_beacons() -> void:
    # Compact warning beacons break up the long perimeter walls and reinforce
    # the industrial facility theme. They are emissive meshes only: no lights,
    # collision, shadows, or navigation changes.
    var housing_material := StandardMaterial3D.new()
    housing_material.albedo_color = Color(0.035, 0.055, 0.068)
    housing_material.metallic = 0.72
    housing_material.roughness = 0.42

    var cyan_material := _make_beacon_material(Color(0.06, 0.72, 0.96))
    var amber_material := _make_beacon_material(Color(1.0, 0.42, 0.10))

    for side in [-1.0, 1.0]:
        for index in range(3):
            var z := -8.0 + float(index) * 8.0
            var beacon := Node3D.new()
            beacon.name = "PerimeterBeacon_%s_%02d" % ["L" if side < 0.0 else "R", index + 1]
            beacon.position = Vector3(side * 16.35, 3.35, z)
            add_child(beacon)

            _add_box(beacon, Vector3.ZERO, Vector3(0.72, 0.34, 1.45), housing_material)
            _add_box(beacon, Vector3(-side * 0.13, 0.0, 0.0), Vector3(0.10, 0.22, 1.12), cyan_material)
            _add_box(beacon, Vector3(-side * 0.19, 0.0, 0.0), Vector3(0.07, 0.16, 0.78), amber_material)


func _make_beacon_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color * 0.72
    material.emission_energy_multiplier = 0.9
    status_materials.append(material)
    status_phases.append(float(status_materials.size()) * 0.9)
    return material
