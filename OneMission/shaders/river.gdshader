shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.08, 0.19, 0.23, 1.0);
varying vec2 surface;
void vertex() {
    surface = VERTEX.xz;
    float first = VERTEX.x * 0.28 + TIME * 0.8;
    float second = VERTEX.z * 0.9 - TIME * 1.3;
    VERTEX.y += 0.045 * sin(first) + 0.025 * sin(second);
    NORMAL = normalize(vec3(-0.0126 * cos(first), 1.0, -0.0225 * cos(second)));
}
void fragment() {
    float bank = smoothstep(7.5, 8.8, abs(surface.y));
    float foam = bank * (0.5 + 0.5 * sin(surface.x * 1.6 - TIME));
    ALBEDO = mix(water_color.rgb, vec3(0.35, 0.45, 0.45), foam * 0.35);
    ROUGHNESS = 0.19;
    METALLIC = 0.08;
}
