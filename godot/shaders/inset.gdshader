// The art window: a rounded panel sunk into the card. Inner shadow from the top-left,
// a light bevel on the bottom-right, a soft spotlight and a faint checker backdrop.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(220.0, 140.0);
uniform vec4 bg_a : source_color = vec4(1.0, 0.94, 0.88, 1.0);
uniform vec4 bg_b : source_color = vec4(0.97, 0.79, 0.66, 1.0);
uniform vec4 shade : source_color = vec4(0.5, 0.2, 0.3, 1.0);
uniform float radius = 10.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 hs = rect_size * 0.5;
	vec2 q = p - hs;
	float d = sd_box(q, hs - vec2(1.0), radius);
	// backdrop: soft checker, spotlight in the middle
	vec2 cell = floor(p / 14.0);
	float chk = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(bg_a.rgb, mix(bg_a.rgb, bg_b.rgb, 0.45), chk);
	float spot = 1.0 - smoothstep(0.0, 0.75, length(q / hs * vec2(0.8, 1.0)));
	col = mix(col, vec3(1.0), spot * 0.35);
	// floor
	float fl = smoothstep(rect_size.y - 22.0, rect_size.y - 20.0, p.y);
	col = mix(col, bg_b.rgb * 0.95, fl * 0.6);
	// inner shadow from the top and left edges
	float top = 1.0 - smoothstep(0.0, 9.0, p.y);
	float left = 1.0 - smoothstep(0.0, 7.0, p.x);
	col = mix(col, shade.rgb, max(top * 0.55, left * 0.4));
	// bevels
	float rim = 1.0 - smoothstep(0.8, 2.0, -d);
	vec2 n = normalize(q + vec2(0.0001));
	float lit = smoothstep(-0.2, 0.6, dot(n, normalize(vec2(1.0, 1.0))));
	col = mix(col, mix(shade.rgb * 0.8, vec3(1.0), lit), rim);
	COLOR = vec4(col, fill_aa(d));
}
