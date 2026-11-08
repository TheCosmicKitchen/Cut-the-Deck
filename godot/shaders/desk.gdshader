// A warm wooden desk for the paper world.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(1920.0, 1080.0);

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * rect_size;
	float plank = floor(p.y / 180.0);
	vec2 q = vec2(p.x * 0.004, p.y * 0.05) + vec2(plank * 13.0, 0.0);
	float grain = vnoise(q * vec2(1.0, 1.0) + vnoise(q * 3.0) * 1.5);
	float rings = fract(grain * 6.0);
	vec3 a = vec3(0.47, 0.30, 0.19);
	vec3 b = vec3(0.36, 0.22, 0.13);
	vec3 col = mix(a, b, smoothstep(0.2, 0.8, rings) * 0.7);
	col *= 0.92 + hash12(vec2(plank, 3.0)) * 0.12;
	float seam = 1.0 - smoothstep(0.0, 2.0, abs(mod(p.y, 180.0) - 1.0));
	col *= 1.0 - seam * 0.35;
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 0.7;
	COLOR = vec4(col, 1.0);
}
