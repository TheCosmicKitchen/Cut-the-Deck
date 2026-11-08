// A rounded candy-striped frame with a hard drop shadow, drawn smoothly at any size.
// The ColorRect is the box plus room for the shadow (shadow.x, shadow.y px).
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(300.0, 400.0);
uniform vec2 shadow = vec2(10.0, 10.0);
uniform vec4 shadow_col : source_color = vec4(0.75, 0.16, 0.47, 1.0);
uniform float radius = 16.0;
uniform float band = 12.0;
uniform float edge_w = 2.5;
uniform float period = 18.0;
uniform vec4 edge : source_color = vec4(0.47, 0.38, 0.91, 1.0);
uniform vec4 s1 : source_color = vec4(0.47, 0.38, 0.91, 1.0);
uniform vec4 s2 : source_color = vec4(0.97, 0.79, 0.66, 1.0);
uniform vec4 s3 : source_color = vec4(1.0, 0.96, 0.92, 1.0);
uniform vec4 rule : source_color = vec4(0.74, 0.67, 0.97, 1.0);
uniform vec4 fill : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float scroll = 0.0;
uniform float glow = 0.0;          // selection halo
uniform vec4 glow_col : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float dim = 0.0;

vec3 stripes(vec2 p) {
	float t = fract((p.x + p.y + scroll) / period);
	float aa = 1.2 / period;
	float a = smoothstep(0.42 - aa, 0.42 + aa, t) - smoothstep(1.0 - aa, 1.0, t);
	float b = smoothstep(0.66 - aa, 0.66 + aa, t) - smoothstep(1.0 - aa, 1.0, t);
	vec3 c = s1.rgb;
	c = mix(c, s2.rgb, a);
	c = mix(c, s3.rgb, b);
	return c;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 box = rect_size - shadow;
	vec2 hs = box * 0.5;
	vec2 c = hs;
	float d = sd_box(p - c, hs, radius);
	float ds = sd_box(p - c - shadow, hs, radius);
	vec4 o = vec4(shadow_col.rgb, fill_aa(ds) * shadow_col.a);
	if (glow > 0.0) {
		float g = (1.0 - smoothstep(0.0, 10.0, d)) * step(0.0, d) * glow;
		o = mix(o, vec4(glow_col.rgb, 1.0), g);
		o.a = max(o.a, g);
	}
	float depth = -d;
	vec3 col;
	if (depth < edge_w) {
		col = edge.rgb;
	} else if (depth < band) {
		col = stripes(p);
		// soft inner shading so the band looks rounded
		col *= 0.92 + 0.08 * smoothstep(edge_w, band, depth);
	} else if (depth < band + 2.5) {
		col = rule.rgb;
	} else {
		col = fill.rgb;
		float inner = abs(depth - (band + 7.0));
		col = mix(col, rule.rgb, (1.0 - smoothstep(0.6, 1.4, inner)) * 0.45);
		// a gentle top gloss on the panel
		col = mix(col, vec3(1.0), 0.0);
	}
	// anti-alias the boundaries between rings
	float aa_edge = smoothstep(edge_w - 0.6, edge_w + 0.6, depth);
	float aa_band = smoothstep(band - 0.6, band + 0.6, depth);
	float aa_rule = smoothstep(band + 1.9, band + 3.1, depth);
	vec3 ring = mix(edge.rgb, stripes(p) * (0.92 + 0.08 * smoothstep(edge_w, band, depth)), aa_edge);
	ring = mix(ring, rule.rgb, aa_band);
	ring = mix(ring, col, aa_rule);
	col = depth < band + 3.5 ? ring : col;
	col = mix(col, vec3(dot(col, vec3(0.33))), dim * 0.5);
	col *= 1.0 - dim * 0.18;
	o = mix(o, vec4(col, 1.0), fill_aa(d));
	COLOR = o;
}
