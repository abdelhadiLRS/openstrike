extends Node3D

## Low-cost objective-zone paint that improves site recognition from ground level.
## All elements are render-only: no colliders, lights, particles, or navigation.

const SITE_DATA := [
    {"code": "A", "name": "ALPHA", "position": Vector3(-10.0, 0.0, -7.0), "color": Color(0.12, 0.72, 0.96)},
    {"code": "B", "name": "BRAVO", "position": Vector3(10.0, 0.0, 7.0), "color": Color(1.0, 0.58, 0.20)}
]


func _ready() -> void:
    for site in SITE_DATA:
        _build_site_stencil(site)


func _build_site_stencil(site: Dictionary) -> void:
    var center: Vector3 = site["position"]
    var accent: Color = site["color"]
    var paint := StandardMaterial3D.new()
    paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    paint.albedo_color = Color(accent.r, accent.g, accent.b, 0.76)
    paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    paint.roughness = 1.0

    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.035, 0.045, 0.052, 0.92)
    dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    dark.roughness = 1.0

    # Four short, broken perimeter bars create a readable site boundary while
    # leaving the existing center ring and player approach lanes unobstructed.
    for side in [-1.0, 1.0]:
        for axis in [-1.0, 1.0]:
            var offset := Vector3(side * 2.35, 0.025, axis * 2.35)
            var bar := _add_box(center + offset, Vector3(1.05, 0.018, 0.075), paint)
            bar.rotation.y = -0.42 if side == axis else 0.42

    # Three small approach chevrons point from each site back toward mid.
    var toward_mid := Vector3(-center.x, 0.0, -center.z).normalized()
    var side_axis := Vector3(toward_mid.z, 0.0, -toward_mid.x)
    var heading := atan2(-toward_mid.z, toward_mid.x)
    for index in range(3):
        var distance := 4.0 + float(index) * 0.72
        var mark_center := center + toward_mid * distance
        var left := _add_box(mark_center - side_axis * 0.16 + Vector3(0.0, 0.022, 0.0), Vector3(0.42, 0.014, 0.055), paint)
        var right := _add_box(mark_center + side_axis * 0.16 + Vector3(0.0, 0.022, 0.0), Vector3(0.42, 0.014, 0.055), paint)
        left.rotation.y = heading - 0.58
        right.rotation.y = heading + 0.58

    # Floor stencil uses a dark backing and a restrained team-color title.
    var backing := _add_box(center + Vector3(0.0, 0.019, -1.55), Vector3(2.45, 0.012, 0.72), dark)
    backing.name = "SiteStencilBacking_" + str(site["code"])
    var label := Label3D.new()
    label.name = "SiteStencil_" + str(site["code"])
    label.text = str(site["code"]) + "  /  " + str(site["name"])
    label.position = center + Vector3(0.0, 0.034, -1.55)
    label.rotation_degrees.x = -90.0
    label.font_size = 52
    label.pixel_size = 0.009
    label.modulate = accent
    label.outline_size = 5
    label.outline_modulate = Color(0.015, 0.022, 0.028, 0.95)
    label.shaded = false
    add_child(label)


func _add_box(world_position: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    instance.mesh = mesh
    instance.position = world_position
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    return instance
