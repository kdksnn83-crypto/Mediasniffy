shader_type spatial;
uniform float wetness : hint_range(0.0, 1.0) = 0.85;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float patches = noise(world_position.xz * 0.35);
    float grit = noise(world_position.xz * 32.0);
    ALBEDO = mix(vec3(0.15, 0.19, 0.115), vec3(0.27, 0.235, 0.18), smoothstep(0.28, 0.7, patches));
    ALBEDO *= 0.8 + grit * 0.3;
    ALBEDO *= 1.0 - wetness * 0.12;
    ROUGHNESS = mix(0.93, 0.47, wetness);
}
