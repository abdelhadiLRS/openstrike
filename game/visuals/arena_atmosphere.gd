extends Node3D

## A tiny GPU-only dust layer that gives the arena depth without adding
## collision, lights, shadows, or navigation work. Disabled in low-spec mode.

var particles: GPUParticles3D


func _ready() -> void:
    _build_particles()


func set_enabled(enabled: bool) -> void:
    if is_instance_valid(particles):
        particles.emitting = enabled


func _process(_delta: float) -> void:
    # Read the root's runtime quality toggle so F4 also controls this effect.
    var root := get_parent()
    if is_instance_valid(root) and root.get("low_spec_mode") != null:
        var enabled := not bool(root.get("low_spec_mode"))
        if particles.emitting != enabled:
            particles.emitting = enabled


func _build_particles() -> void:
    particles = GPUParticles3D.new()
    particles.name = "AmbientDust"
    particles.amount = 28
    particles.lifetime = 9.0
    particles.preprocess = 3.0
    particles.randomness = 1.0
    particles.emitting = true
    particles.visibility_aabb = AABB(Vector3(-18.0, -0.5, -18.0), Vector3(36.0, 7.0, 36.0))

    var process_material := ParticleProcessMaterial.new()
    process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process_material.emission_box_extents = Vector3(15.5, 2.2, 15.5)
    process_material.direction = Vector3(0.18, 0.08, 0.0)
    process_material.spread = 38.0
    process_material.initial_velocity_min = 0.025
    process_material.initial_velocity_max = 0.095
    process_material.gravity = Vector3(0.0, 0.012, 0.0)
    process_material.scale_min = 0.45
    process_material.scale_max = 1.1
    process_material.damping_min = 0.01
    process_material.damping_max = 0.04

    # Fade each mote in and out over its lifetime so the dust reads as soft
    # atmospheric depth instead of a constant-opacity square sprite.
    var dust_gradient := Gradient.new()
    dust_gradient.set_color(0, Color(0.72, 0.82, 0.9, 0.0))
    dust_gradient.add_point(0.18, Color(0.72, 0.82, 0.9, 0.12))
    dust_gradient.add_point(0.72, Color(0.72, 0.82, 0.9, 0.10))
    dust_gradient.set_color(1, Color(0.72, 0.82, 0.9, 0.0))
    var dust_ramp := GradientTexture1D.new()
    dust_ramp.gradient = dust_gradient
    process_material.color_ramp = dust_ramp
    particles.process_material = process_material

    var quad := QuadMesh.new()
    quad.size = Vector2(0.035, 0.035)
    var dust_material := StandardMaterial3D.new()
    dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    dust_material.albedo_color = Color(0.72, 0.82, 0.9, 0.14)
    dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    dust_material.no_depth_test = false
    quad.material = dust_material
    particles.draw_pass_1 = quad
    add_child(particles)
