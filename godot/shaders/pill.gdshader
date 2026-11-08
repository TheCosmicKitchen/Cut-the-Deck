// A chunk of card text as a glossy candy pill. States: muted, redacted, enemy edit,
// telegraph (animated red dashes), fits/hover (golden ring), empty slot (dashed outline).
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(120.0, 36.0);
uniform float margin = 6.0;
uniform vec4 col : source_color = vec4(0.91, 0.22, 0.35, 1.0);
uniform vec4 line : source_color = vec4(0.6, 0.1, 0.25, 1.0);
uniform bool muted = false;
uniform bool redacted = false;
uniform bool enemy_edit = false;
uniform bool telegraph = false;
uniform bool fits = false;
uniform bool empty = false;
uniform float hover = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 hs = rect_size * 0.5 - vec2(margin);
	vec2 q = p - rect_size * 0.5;
	float r = min(hs.y, 12.0);
	float d = sd_box(q, hs, r);
	vec4 o = vec4(0.0);
	if (empty) {
		float ring = 1.0 - smoothstep(0.7, 1.6, abs(d));
		float dash = step(0.5, fract((p.x + p.y * 0.4) / 9.0));
		vec3 c = fits ? vec3(0.98, 0.72, 0.1) : line.rgb;
		o = vec4(c, ring * dash * (fits ? 1.0 : 0.6));
		if (fits) o = mix(o, vec4(1.0, 0.85, 0.3, 0.25), fill_aa(d) * 0.6);
	} else {
		vec3 c = col.rgb;
		vec3 ln = line.rgb;
		if (muted) { c = vec3(0.86, 0.84, 0.9); ln = vec3(0.6, 0.58, 0.68); }
		if (redacted) { c = vec3(0.07, 0.06, 0.1); ln = c; }
		// hard drop shadow under the pill
		float ds = sd_box(q - vec2(0.0, 2.5), hs, r);
		o = vec4(ln * 0.8, fill_aa(ds) * 0.5);
		// body: vertical gradient, gloss on the top half, outline
		float t = (q.y + hs.y) / (hs.y * 2.0);
		vec3 body = mix(c * 1.12, c * 0.9, t);
		float gloss = (1.0 - smoothstep(0.0, 0.5, t)) * smoothstep(-1.0, 2.0, -d - 2.5);
		body = mix(body, vec3(1.0), gloss * (redacted ? 0.05 : 0.28));
		if (redacted) {
			body += (hash12(floor(p / 2.0) + seed) - 0.5) * 0.06;
		}
		float outline = 1.0 - smoothstep(1.2, 2.2, -d);
		body = mix(body, ln, outline);
		o = mix(o, vec4(body, 1.0), fill_aa(d));
		if (muted && !redacted) {
			float y = q.y - q.x * 0.08 - sin(p.x * 0.25 + seed) * 1.5;
			float s = (1.0 - smoothstep(1.0, 2.2, abs(y))) * step(abs(q.x), hs.x + 3.0);
			o = mix(o, vec4(0.15, 0.1, 0.3, 1.0), s);
		}
		if (enemy_edit) {
			float w = q.y - (hs.y + 3.0) - sin(p.x * 0.55) * 1.6;
			float s = (1.0 - smoothstep(0.7, 1.7, abs(w))) * step(abs(q.x), hs.x);
			o = mix(o, vec4(0.92, 0.18, 0.3, 1.0), s);
		}
	}
	if (telegraph) {
		float ring = 1.0 - smoothstep(1.0, 2.2, abs(d - 3.5));
		float dash = step(0.5, fract((p.x - p.y) / 10.0 + TIME * 0.9));
		o = mix(o, vec4(0.92, 0.18, 0.3, 1.0), ring * dash);
	}
	if (fits || hover > 0.0) {
		float ring = 1.0 - smoothstep(1.0, 2.4, abs(d - 3.5));
		o = mix(o, vec4(1.0, 0.8, 0.15, 1.0), ring * max(fits && !empty ? 1.0 : 0.0, hover));
	}
	COLOR = o;
}
