// Pink backdrop: soft diagonal pattern of stars and little scissors-dots, and a vignette.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec4 base : source_color = vec4(0.98, 0.72, 0.84, 1.0);
uniform vec4 motif : source_color = vec4(0.95, 0.6, 0.77, 1.0);
uniform float cell = 96.0;
uniform float drift = 0.0;

float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0, 1);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void fragment() {
	vec2 p = UV * rect_size + vec2(drift, drift * 0.5);
	vec2 g = p / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float alt = mod(id.x + id.y, 2.0);
	float d;
	if (alt < 0.5) {
		d = sd_star(f * cell * vec2(1.0, -1.0), 15.0, 0.48) - 2.0;
	} else {
		d = length(f * cell) - 7.0;
	}
	vec3 col = mix(base.rgb, motif.rgb, fill_aa(d));
	vec2 uv = UV - 0.5;
	col *= 1.0 - dot(uv, uv) * 0.25;
	COLOR = vec4(col, 1.0);
}
