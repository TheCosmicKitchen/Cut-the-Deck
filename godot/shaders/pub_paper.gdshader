// Paper stock for the six publications, used for whole cards (mode 0) and for
// slips cut from them (mode 1).
//   pub 0 newspaper  newsprint, fibres, faint column rules, scissor-cut edges
//   pub 1 comics     cream with Ben-Day dots, clean edges
//   pub 2 pulp       yellowed paperback page, age spots, worn corners
//   pub 3 zine       photocopy: grey speckle, copier shadow, skewed
//   pub 4 manual     clean white with a pale blue grid, crisp
//   pub 5 almanac    aged cream, foxing, deckled edges
shader_type canvas_item;
#include "res://shaders/sdf.gdshaderinc"

uniform vec2 rect_size = vec2(270.0, 390.0);
uniform float margin = 14.0;
uniform int pub = 0;
uniform int mode = 0;
uniform float seed = 0.0;
uniform float shadow = 1.0;
uniform bool glue = false;

float n1(float x, float s) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash12(vec2(i, s)), hash12(vec2(i + 1.0, s)), f * f * (3.0 - 2.0 * f));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

// the outline: a quad with jittered corners; wob = how ragged each edge is
float outline(vec2 p, vec2 lo, vec2 hi, float jit, float wob_amt, float freq) {
	vec2 a = lo + (vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0))) - 0.5) * jit;
	vec2 b = vec2(hi.x, lo.y) + (vec2(hash12(vec2(seed, 3.0)), hash12(vec2(seed, 4.0))) - 0.5) * jit;
	vec2 c = hi + (vec2(hash12(vec2(seed, 5.0)), hash12(vec2(seed, 6.0))) - 0.5) * jit;
	vec2 d = vec2(lo.x, hi.y) + (vec2(hash12(vec2(seed, 7.0)), hash12(vec2(seed, 8.0))) - 0.5) * jit;
	vec2 pts[4] = vec2[4](a, b, c, d);
	float dist = -1e9;
	for (int i = 0; i < 4; i++) {
		vec2 e0 = pts[i];
		vec2 e1 = pts[(i + 1) % 4];
		vec2 e = normalize(e1 - e0);
		vec2 nrm = vec2(e.y, -e.x);
		float along = dot(p - e0, e);
		float run_id = floor(along / 11.0 + hash12(vec2(float(i), seed)) * 3.0);
		float w = (hash12(vec2(run_id, float(i) + seed)) - 0.5) * 2.0 * wob_amt;
		w += (n1(along * freq + float(i) * 17.0, seed) - 0.5) * wob_amt;
		dist = max(dist, dot(p - e0, nrm) + w);
	}
	return dist;
}

vec3 stock(vec2 p, vec2 lo, vec2 hi) {
	vec2 q = p + vec2(seed * 37.0, seed * 11.0);
	vec3 col;
	float g = hash12(floor(q));
	if (pub == 0) {
		col = vec3(0.925, 0.902, 0.835);
		col += (vnoise(q * vec2(0.9, 0.12)) - 0.5) * 0.05;          // fibres
		col -= g * 0.025;
		float edge = min(min(p.x - lo.x, hi.x - p.x), min(p.y - lo.y, hi.y - p.y));
		col = mix(col, vec3(0.88, 0.82, 0.66), (1.0 - smoothstep(0.0, 26.0, edge)) * 0.35);
	} else if (pub == 1) {
		col = vec3(1.0, 0.985, 0.93);
		vec2 cell = q / 7.0;
		vec2 gp = fract(vec2(cell.x + cell.y, cell.y - cell.x) * 0.7071) - 0.5;
		float dotm = 1.0 - smoothstep(0.24, 0.30, length(gp));
		col = mix(col, vec3(1.0, 0.87, 0.42), dotm * 0.55);
	} else if (pub == 2) {
		// a painted pulp cover: lurid dusk, brush strokes, canvas weave
		float t = (p.y - lo.y) / max(1.0, hi.y - lo.y);
		vec3 top = vec3(0.16, 0.05, 0.26);
		vec3 mid = vec3(0.62, 0.09, 0.16);
		vec3 low = vec3(0.12, 0.03, 0.08);
		col = mode == 1 ? mix(top, mid, 0.55) : (t < 0.42 ? mix(top, mid, smoothstep(0.0, 0.42, t)) : mix(mid, low, smoothstep(0.42, 1.0, t)));
		vec2 bq = vec2(q.x * 0.7 + q.y * 0.7, q.y * 0.7 - q.x * 0.7);
		float stroke = vnoise(bq * vec2(0.03, 0.28)) + vnoise(bq * vec2(0.08, 0.6)) * 0.5;
		col *= 0.78 + stroke * 0.3;
		col = mix(col, vec3(1.0, 0.55, 0.15), smoothstep(0.95, 1.3, stroke) * 0.25);
		col += (hash12(floor(q * 0.5)) - 0.5) * 0.05;
		float weave = (sin(q.x * 2.1) * sin(q.y * 2.1)) * 0.02;
		col += weave;
		if (mode == 0) {
			// worn corners and edges: the pulp paper shows through
			float edge = min(min(p.x - lo.x, hi.x - p.x), min(p.y - lo.y, hi.y - p.y));
			float wear = (1.0 - smoothstep(0.0, 6.0, edge + vnoise(q * 0.4) * 6.0 - 3.0));
			col = mix(col, vec3(0.86, 0.76, 0.55), wear * 0.85);
		}
	} else if (pub == 3) {
		col = vec3(0.95, 0.945, 0.935);
		col -= step(0.985, g) * 0.6;                               // toner specks
		col -= smoothstep(0.6, 1.0, vnoise(q * vec2(0.02, 0.6))) * 0.05;  // streaks
		float edge = min(min(p.x - lo.x, hi.x - p.x), min(p.y - lo.y, hi.y - p.y));
		col *= mix(0.78, 1.0, smoothstep(0.0, 14.0, edge));         // copier shadow
	} else if (pub == 4) {
		col = vec3(0.995, 0.995, 1.0);
		vec2 gr = abs(fract(q / 12.0) - 0.5) * 12.0;
		float line = 1.0 - smoothstep(0.0, 0.8, min(gr.x, gr.y));
		col = mix(col, vec3(0.86, 0.9, 0.95), line * 0.35);
	} else {
		col = vec3(0.94, 0.87, 0.71);
		float fox = smoothstep(0.8, 0.9, vnoise(q * 0.11)) * smoothstep(0.4, 0.7, vnoise(q * 0.5 + 7.0));
		col = mix(col, vec3(0.78, 0.6, 0.38), fox * 0.3);
		col -= g * 0.03;
		float edge = min(min(p.x - lo.x, hi.x - p.x), min(p.y - lo.y, hi.y - p.y));
		col = mix(col, vec3(0.7, 0.52, 0.3), (1.0 - smoothstep(0.0, 18.0, edge)) * 0.3);
	}
	return col;
}

float shape(vec2 p, vec2 lo, vec2 hi) {
	if (mode == 1) {
		return outline(p, lo, hi, 6.0, 1.1, 0.6);
	}
	if (pub == 0) return outline(p, lo, hi, 5.0, 1.2, 0.6);
	if (pub == 1) return sd_box(p - (lo + hi) * 0.5, (hi - lo) * 0.5, 7.0);
	if (pub == 2) {
		float d = sd_box(p - (lo + hi) * 0.5, (hi - lo) * 0.5, 5.0);
		return d + (vnoise(p * 0.35 + seed) - 0.5) * 1.4;
	}
	if (pub == 3) return outline(p, lo, hi, 7.0, 0.0, 0.0);
	if (pub == 4) return sd_box(p - (lo + hi) * 0.5, (hi - lo) * 0.5, 1.5);
	return outline(p, lo, hi, 2.0, 0.6, 2.2);
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 lo = vec2(margin);
	vec2 hi = rect_size - vec2(margin);
	float d = shape(p, lo, hi);
	float ds = shape(p - (mode == 1 ? vec2(1.8, 3.0) : vec2(4.0, 7.0)), lo, hi);
	float soft = mode == 1 ? 3.0 : 9.0;
	vec4 o = vec4(0.12, 0.07, 0.04, (1.0 - smoothstep(-2.0, soft, ds)) * 0.38 * shadow);
	if (glue && mode == 1) {
		float gl = (1.0 - smoothstep(0.0, 3.0, d)) * step(0.0, d);
		o = mix(o, vec4(1.0, 1.0, 0.94, 0.5), gl * 0.7);
	}
	vec3 col = stock(p, lo, hi);
	if (mode == 1) {
		// a bit of the page the slip was cut from comes with it
		float top = p.y - lo.y;
		float bot = hi.y - p.y;
		float lft = p.x - lo.x;
		if (pub == 0) {
			// clipped mid-article: the tails of the lines above and below
			float dash = step(0.25, fract(p.x / 9.0 + hash12(vec2(floor(p.x / 9.0), seed)) * 0.4));
			col = mix(col, vec3(0.25), dash * (step(top, 2.5) + step(bot, 2.0)) * 0.55);
		} else if (pub == 1) {
			col = mix(col, vec3(0.05), step(top, 3.5));      // the panel's ink border
		} else if (pub == 3) {
			col = mix(col, vec3(1.0, 0.31, 0.6), step(bot, 4.0) * step(0.3, vnoise(p * 0.3)) * 0.8);
		} else if (pub == 4) {
			col = mix(col, vec3(0.12, 0.18, 0.32), step(lft, 3.0));
		} else if (pub == 5) {
			col = mix(col, vec3(0.29, 0.17, 0.09), (step(top, 2.0) + step(abs(top - 4.0), 0.6)) * 0.8);
		}
	}
	// a cut edge catches a little shade
	col *= mix(0.86, 1.0, smoothstep(0.4, 1.8, -d));
	o = mix(o, vec4(col, 1.0), clamp(0.5 - d, 0.0, 1.0));
	COLOR = o;
}
