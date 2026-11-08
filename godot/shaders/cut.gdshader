// Cut paper, for the cut-and-paste look. One shader, three jobs:
//   mode 0  PRINTED: no paper, just faint dotted cut-guides around printed text
//   mode 1  SLIP: a hand-cut paper slip glued on top (rough straight cuts, glue
//           sheen, soft shadow, optional strip of tape)
//   mode 2  HOLE: where a chunk was cut out: the backdrop shows through, with a
//           shadow inside and torn fibres on the rim
// The rough outline is a convex quad with jittered corners plus fine edge noise,
// so it looks scissor-cut rather than rounded.
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(140.0, 44.0);
uniform float margin = 8.0;
uniform int mode = 0;
uniform float seed = 0.0;
uniform vec4 paper : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 tint : source_color = vec4(0.94, 0.29, 0.42, 1.0);
uniform vec4 hole_col : source_color = vec4(0.98, 0.72, 0.84, 1.0);
uniform bool tape = false;
// the card a slip was cut from: its stripe colours [s1, s2, s3] and art ground
uniform vec4 src1 : source_color = vec4(0.94, 0.29, 0.42, 1.0);
uniform vec4 src2 : source_color = vec4(1.0, 0.82, 0.72, 1.0);
uniform vec4 src3 : source_color = vec4(1.0, 0.97, 0.93, 1.0);
uniform bool has_src = false;
uniform int sliver = 0;        // which cut edge shows a bit of the source card's border: 0 none, 1 top, 2 bottom, 3 left
uniform bool glue = true;
uniform float hover = 0.0;
uniform bool telegraph = false;
uniform bool fits = false;

float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	float a = hash12(vec2(i, seed));
	float b = hash12(vec2(i + 1.0, seed));
	return mix(a, b, f * f * (3.0 - 2.0 * f));
}

// signed distance to the rough quad (negative inside)
float rough(vec2 p, vec2 lo, vec2 hi, float jit) {
	vec2 a = lo + (vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0))) - 0.5) * jit;
	vec2 b = vec2(hi.x, lo.y) + (vec2(hash12(vec2(seed, 3.0)), hash12(vec2(seed, 4.0))) - 0.5) * jit;
	vec2 c = hi + (vec2(hash12(vec2(seed, 5.0)), hash12(vec2(seed, 6.0))) - 0.5) * jit;
	vec2 d = vec2(lo.x, hi.y) + (vec2(hash12(vec2(seed, 7.0)), hash12(vec2(seed, 8.0))) - 0.5) * jit;
	float dist = -1e9;
	vec2 pts[4] = vec2[4](a, b, c, d);
	for (int i = 0; i < 4; i++) {
		vec2 e0 = pts[i];
		vec2 e1 = pts[(i + 1) % 4];
		vec2 e = normalize(e1 - e0);
		vec2 nrm = vec2(e.y, -e.x);
		float along = dot(p - e0, e);
		// fine nibble from the scissors, and the odd small notch
		// scissors cut in short straight runs: piecewise wander plus a fine nibble
		float run_id = floor(along / 11.0 + hash12(vec2(float(i), seed)) * 3.0);
		float wob = (hash12(vec2(run_id, float(i) + seed)) - 0.5) * 2.2;
		wob += (n1(along * 0.6 + float(i) * 17.0) - 0.5) * 1.0;
		wob += step(0.93, hash12(vec2(floor(along / 3.0), float(i) * 7.0 + seed))) * 1.6;
		dist = max(dist, dot(p - e0, nrm) + wob);
	}
	return dist;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 lo = vec2(margin);
	vec2 hi = rect_size - vec2(margin);
	vec4 o = vec4(0.0);
	if (mode == 0) {
		// dotted cut-guide on a rounded rect around the word
		float d = sd_box(p - rect_size * 0.5, rect_size * 0.5 - vec2(margin - 1.0), 6.0);
		float ring = 1.0 - smoothstep(0.5, 1.3, abs(d));
		float dots = step(0.55, fract((p.x + p.y * 1.3) / 6.0));
		o = vec4(tint.rgb, ring * dots * (0.45 + hover * 0.5));
		o = mix(o, vec4(tint.rgb, 0.10), fill_aa(d + 1.5) * hover * (1.0 - o.a));
	} else if (mode == 1) {
		float d = rough(p, lo, hi, 7.0);
		float ds = rough(p - vec2(2.0, 3.5), lo, hi, 7.0);
		o = vec4(0.35, 0.1, 0.25, (1.0 - smoothstep(-1.0, 3.0, ds)) * 0.45);
		// wet glue: a glossy translucent rim just outside the cut
		if (glue) {
			float g = (1.0 - smoothstep(0.0, 3.2, d)) * step(0.0, d);
			o = mix(o, vec4(1.0, 1.0, 0.94, 0.55), g * 0.7);
		}
		// the slip is a piece of another card: its pale ground with the checker print
		vec3 col = has_src ? src3.rgb : paper.rgb;
		if (has_src) {
			vec2 cell = floor((p + vec2(seed * 3.0)) / 9.0);
			col = mix(col, mix(src3.rgb, src2.rgb, 0.55), mod(cell.x + cell.y, 2.0));
			// a sliver of that card's candy-stripe border along one cut edge
			float e = sliver == 1 ? p.y - lo.y : (sliver == 2 ? hi.y - p.y : (sliver == 3 ? p.x - lo.x : 99.0));
			if (e < 5.5) {
				float t = fract((p.x + p.y) / 10.0);
				vec3 st = t < 0.42 ? src1.rgb : (t < 0.66 ? src2.rgb : src3.rgb);
				col = mix(col, st, 1.0 - smoothstep(4.5, 5.5, e));
			}
		} else {
			col = mix(col, tint.rgb, 0.12);
		}
		col += (hash12(floor(p)) - 0.5) * 0.03;
		// the cut edge: a thin darker line where the scissors went through
		col = mix(col, (has_src ? src1.rgb : tint.rgb) * 0.55, (1.0 - smoothstep(0.6, 1.6, -d)) * 0.75);
		o = mix(o, vec4(col, 1.0), clamp(0.5 - d, 0.0, 1.0));
		// glue sheen across the slip
		float sheen = (1.0 - smoothstep(0.0, 4.0, abs(p.y - p.x * 0.25 - rect_size.y * 0.15 - mod(seed, 7.0) * 3.0)));
		o.rgb = mix(o.rgb, vec3(1.0), sheen * 0.18 * o.a);
		if (tape) {
			vec2 tc = vec2(lo.x + 2.0, rect_size.y * 0.5);
			vec2 tq = p - tc;
			float a = 0.5 + (hash12(vec2(seed, 9.0)) - 0.5) * 0.4;
			vec2 tr = vec2(cos(a) * tq.x - sin(a) * tq.y, sin(a) * tq.x + cos(a) * tq.y);
			float td = sd_box(tr, vec2(6.0, rect_size.y * 0.42), 1.0);
			float zig = abs(fract(tr.x * 0.5) - 0.5) * 1.2;
			float tm = clamp(0.5 - (td + zig * step(abs(tr.y), 99.0) * 0.0), 0.0, 1.0);
			o = mix(o, vec4(1.0, 0.98, 0.88, 1.0), tm * 0.55);
		}
	} else {
		float d = rough(p, lo, hi, 6.0);
		// inside: the backdrop, in shadow under the top and left edges of the card
		float top = clamp((p.y - lo.y) / 9.0, 0.0, 1.0);
		float left = clamp((p.x - lo.x) / 7.0, 0.0, 1.0);
		float shade = min(top, left);
		vec3 col = hole_col.rgb * mix(0.55, 0.92, shade);
		col += (hash12(floor(p / 2.0)) - 0.5) * 0.03;
		float inside = clamp(0.5 - d, 0.0, 1.0);
		o = vec4(col, inside);
		// torn fibres: a ragged pale rim, thicker where the cut was rough
		float rim_w = 1.4 + n1((p.x + p.y) * 0.7) * 2.2;
		float rim = (1.0 - smoothstep(rim_w - 0.8, rim_w, abs(d))) * step(-rim_w, d);
		o = mix(o, vec4(1.0, 0.99, 0.97, 1.0), rim);
		// the card's cut edge casts a dark line on the inside
		float lip = (1.0 - smoothstep(0.0, 2.2, -d - rim_w)) * step(0.0, -d - rim_w * 0.5);
		o.rgb = mix(o.rgb, hole_col.rgb * 0.35, lip * 0.6 * (1.0 - shade * 0.5));
		if (fits) {
			float ring = 1.0 - smoothstep(1.0, 2.5, abs(d - 3.5));
			o = mix(o, vec4(1.0, 0.78, 0.15, 1.0), ring);
		}
	}
	if (telegraph) {
		float d = sd_box(p - rect_size * 0.5, rect_size * 0.5 - vec2(2.5), 7.0);
		float ring = 1.0 - smoothstep(0.8, 2.0, abs(d));
		float dash = step(0.5, fract((p.x - p.y) / 10.0 + TIME * 0.9));
		o = mix(o, vec4(0.92, 0.18, 0.3, 1.0), ring * dash);
	}
	if (hover > 0.0 && mode != 0) {
		float d = sd_box(p - rect_size * 0.5, rect_size * 0.5 - vec2(2.5), 7.0);
		float ring = 1.0 - smoothstep(0.8, 2.0, abs(d));
		o = mix(o, vec4(1.0, 0.78, 0.15, 1.0), ring * hover);
	}
	COLOR = o;
}
