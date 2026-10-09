shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float wetness : hint_range(0.0, 1.0) = 0.85;
uniform float phase = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    if (r > 1.0) { discard; }
    float ring = sin(r * 42.0 - TIME * 7.0 + phase) * exp(-r * 1.8);
    ALBEDO = vec3(0.12, 0.2, 0.22) + ring * 0.012;
    ROUGHNESS = mix(0.65, 0.13, wetness);
    METALLIC = 0.12;
    NORMAL_MAP = vec3(0.5 + ring * p.x * 0.07, 0.5 + ring * p.y * 0.07, 1.0);
    ALPHA = (1.0 - smoothstep(0.8, 1.0, r)) * wetness * 0.8;
}
