// The cost gem: a glossy round badge with an outline and a hard shadow.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(56.0);
uniform vec4 col : source_color = vec4(0.14, 0.09, 0.28, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool empty = false;
uniform float pulse = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 c = rect_size * 0.5 - vec2(1.5);
	float r = rect_size.x * 0.5 - 5.0;
	float d = length(p - c) - r;
	float ds = length(p - c - vec2(3.0, 3.0)) - r;
	vec4 o = vec4(0.75, 0.16, 0.47, fill_aa(ds));
	if (empty) {
		float rg = 1.0 - smoothstep(0.8, 1.8, abs(d + 2.0));
		float dash = step(0.5, fract(atan(p.y - c.y, p.x - c.x) * 1.9));
		o = vec4(0.62, 0.58, 0.74, rg * dash);
		o = mix(o, vec4(1.0, 1.0, 1.0, 0.9), fill_aa(d + 3.0));
	} else {
		vec2 g = (p - c) / r;
		vec3 body = mix(col.rgb * 1.5 + 0.08, col.rgb, smoothstep(-0.9, 0.7, g.y + g.x * 0.3));
		float gloss = 1.0 - smoothstep(0.0, 0.5, length(g - vec2(-0.32, -0.42)));
		body = mix(body, vec3(1.0), gloss * 0.35);
		float rim = 1.0 - smoothstep(2.0, 3.2, -d);
		body = mix(body, ring.rgb, rim);
		body += pulse * 0.3;
		o = mix(o, vec4(body, 1.0), fill_aa(d));
	}
	COLOR = o;
}
