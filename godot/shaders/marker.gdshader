// Marker strokes drawn over text: a black redaction bar, a scribbled strike-through
// (muted), or a red-pen correction (enemy edit). Rough, hand-drawn edges.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(140.0, 44.0);
uniform int mode = 0;      // 0 redact bar, 1 strike scribble, 2 red-pen underline + circle tick
uniform float seed = 0.0;
uniform float margin = 8.0;

float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash12(vec2(i, seed)), hash12(vec2(i + 1.0, seed)), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 p = UV * rect_size;
	vec4 o = vec4(0.0);
	float x0 = margin - 3.0;
	float x1 = rect_size.x - margin + 3.0;
	if (mode == 0) {
		float top = margin + 1.0 + (n1(p.x * 0.07) - 0.5) * 4.0;
		float bot = rect_size.y - margin - 1.0 + (n1(p.x * 0.06 + 9.0) - 0.5) * 4.0;
		float l = x0 + (n1(p.y * 0.3) - 0.5) * 5.0;
		float r = x1 + (n1(p.y * 0.3 + 4.0) - 0.5) * 5.0;
		float inside = step(top, p.y) * step(p.y, bot) * step(l, p.x) * step(p.x, r);
		// streaky marker ink
		float streak = n1(p.y * 0.9 + 3.0) * 0.08;
		o = vec4(vec3(0.08, 0.06, 0.12) + streak, inside);
	} else if (mode == 1) {
		float y = rect_size.y * 0.5 + sin(p.x * 0.22 + seed) * 2.2 + (p.x - rect_size.x * 0.5) * 0.04;
		float y2 = rect_size.y * 0.5 + 4.0 + sin(p.x * 0.17 + seed * 2.0) * 2.0 - (p.x - rect_size.x * 0.5) * 0.05;
		float s = max(1.0 - smoothstep(1.2, 2.4, abs(p.y - y)), 1.0 - smoothstep(1.0, 2.2, abs(p.y - y2)));
		s *= step(x0, p.x) * step(p.x, x1);
		o = vec4(0.17, 0.11, 0.33, s);
	} else {
		float y = rect_size.y - margin + 2.0 + sin(p.x * 0.5 + seed) * 1.6;
		float s = (1.0 - smoothstep(1.0, 2.1, abs(p.y - y))) * step(x0 + 2.0, p.x) * step(p.x, x1 - 2.0);
		o = vec4(0.9, 0.16, 0.26, s);
	}
	COLOR = o;
}
