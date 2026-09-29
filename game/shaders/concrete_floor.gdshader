shader_type spatial;
render_mode diffuse_burley;

varying vec3 world_position;

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
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = world_position.xz;
    float broad = value_noise(uv * 0.22);
    float grain = value_noise(uv * 2.8);
    float fine = hash2(floor(uv * 18.0));
    float texture_mix = broad * 0.58 + grain * 0.30 + fine * 0.12;
    vec3 concrete_dark = vec3(0.135, 0.155, 0.175);
    vec3 concrete_light = vec3(0.205, 0.220, 0.235);
    ALBEDO = mix(concrete_dark, concrete_light, smoothstep(0.22, 0.78, texture_mix));
    ROUGHNESS = 0.94;
    METALLIC = 0.015;
}
