shader_type spatial;
render_mode diffuse_burley;

varying vec2 wall_uv;

float hash2(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 local = fract(p);
    vec2 blend = local * local * (3.0 - 2.0 * local);
    float a = hash2(cell);
    float b = hash2(cell + vec2(1.0, 0.0));
    float c = hash2(cell + vec2(0.0, 1.0));
    float d = hash2(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void vertex() {
    wall_uv = UV;
}

void fragment() {
    float broad = value_noise(wall_uv * vec2(7.0, 3.0));
    float grain = value_noise(wall_uv * vec2(88.0, 42.0));
    float speckle = hash2(floor(wall_uv * vec2(230.0, 120.0)));
    float variation = broad * 0.54 + grain * 0.30 + speckle * 0.16;

    vec3 concrete_dark = vec3(0.075, 0.095, 0.115);
    vec3 concrete_light = vec3(0.145, 0.165, 0.185);
    vec3 panel_color = mix(concrete_dark, concrete_light, smoothstep(0.18, 0.82, variation));

    float x_phase = fract(wall_uv.x * 8.0);
    float y_phase = fract(wall_uv.y * 5.0);
    float x_edge = min(x_phase, 1.0 - x_phase);
    float y_edge = min(y_phase, 1.0 - y_phase);
    float vertical_seam = 1.0 - smoothstep(0.008, 0.026, x_edge);
    float horizontal_seam = 1.0 - smoothstep(0.008, 0.026, y_edge);
    float seam = max(vertical_seam, horizontal_seam);

    // Subtle vertical grime and lower-wall dirt break up the perfectly clean
    // procedural panels without texture maps or additional geometry.
    float streaks = value_noise(vec2(floor(wall_uv.x * 74.0) * 0.17, wall_uv.y * 11.0));
    float lower_grime = 1.0 - smoothstep(0.10, 0.78, wall_uv.y);
    float grime = clamp((0.5 - streaks) * 0.11 + lower_grime * 0.07, 0.0, 0.13);
    float panel_edge = 1.0 - smoothstep(0.0, 0.045, min(min(x_phase, 1.0 - x_phase), min(y_phase, 1.0 - y_phase)));
    float edge_lift = panel_edge * 0.025;

    ALBEDO = panel_color * (1.0 - seam * 0.30 - grime) + vec3(edge_lift);
    ROUGHNESS = 0.88;
    METALLIC = 0.035;
}
