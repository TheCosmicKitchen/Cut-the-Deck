// The card picture, printed the way each publication prints pictures.
//   0 newspaper  grey halftone
//   1 comics     flat colours, ink outlines, dot shading
//   2 pulp       lurid two-tone with grain and a dark vignette
//   3 zine       photocopied black and white with one riso colour
//   4 manual     clean line drawing
//   5 almanac    woodcut: brown ink, hatched shading
shader_type canvas_item;

uniform int pub = 0;
uniform vec2 rect_size = vec2(230.0, 120.0);
uniform vec4 accent : source_color = vec4(1.0, 0.29, 0.6, 1.0);

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float edge(sampler2D t, vec2 uv, vec2 px) {
	float tl = luma(texture(t, uv + px * vec2(-1, -1)).rgb);
	float tc = luma(texture(t, uv + px * vec2(0, -1)).rgb);
	float tr = luma(texture(t, uv + px * vec2(1, -1)).rgb);
	float ml = luma(texture(t, uv + px * vec2(-1, 0)).rgb);
	float mr = luma(texture(t, uv + px * vec2(1, 0)).rgb);
	float bl = luma(texture(t, uv + px * vec2(-1, 1)).rgb);
	float bc = luma(texture(t, uv + px * vec2(0, 1)).rgb);
	float br = luma(texture(t, uv + px * vec2(1, 1)).rgb);
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	return length(vec2(gx, gy));
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = luma(c);
	vec2 p = UV * rect_size;
	vec3 o;
	float alpha = 1.0;
	if (pub == 0) {
		// halftone: dot size from darkness on a 45 degree grid
		float cellsz = 3.2;
		vec2 r = vec2(p.x + p.y, p.y - p.x) * 0.7071 / cellsz;
		vec2 f = fract(r) - 0.5;
		float rad = sqrt(1.0 - clamp(l * 1.1 - 0.05, 0.0, 1.0)) * 0.62;
		float ink = 1.0 - smoothstep(rad - 0.08, rad + 0.08, length(f));
		o = mix(vec3(0.9, 0.88, 0.82), vec3(0.1, 0.1, 0.12), ink);
	} else if (pub == 1) {
		vec3 q = floor(c * 3.0 + 0.5) / 3.0;
		q = clamp(mix(vec3(luma(q)), q, 1.5), 0.0, 1.0);
		vec2 f = fract(p / 4.0) - 0.5;
		float shade = step(l, 0.62) * (1.0 - smoothstep(0.18, 0.24, length(f)));
		q = mix(q, q * 0.72, shade);
		float e = max(edge(TEXTURE, UV, px * 2.0), edge(TEXTURE, UV, px));
		o = mix(q, vec3(0.05), smoothstep(0.18, 0.35, e));
	} else if (pub == 2) {
		// painted: smear the picture along brush strokes, then map it to lurid paint
		vec2 smear = vec2(hash(floor(p / vec2(6.0, 2.0))) - 0.5, hash(floor(p / vec2(2.0, 6.0)) + 3.1) - 0.5) * px * 3.0;
		float ls = luma(texture(TEXTURE, UV + smear).rgb);
		vec3 sat = texture(TEXTURE, UV + smear).rgb;
		vec3 g0 = vec3(0.12, 0.03, 0.2);
		vec3 g1 = vec3(0.62, 0.08, 0.2);
		vec3 g2 = vec3(0.98, 0.45, 0.12);
		vec3 g3 = vec3(1.0, 0.9, 0.45);
		float k = smoothstep(0.15, 0.95, ls);
		o = k < 0.33 ? mix(g0, g1, k / 0.33) : (k < 0.66 ? mix(g1, g2, (k - 0.33) / 0.33) : mix(g2, g3, (k - 0.66) / 0.34));
		o = mix(o, sat * vec3(1.15, 0.9, 0.8), 0.28);
		// rim light on edges
		float e = edge(TEXTURE, UV, px * 1.5);
		o = mix(o, vec3(1.0, 0.85, 0.4), smoothstep(0.25, 0.6, e) * 0.55);
		o += (hash(floor(p * 0.5)) - 0.5) * 0.06;
		vec2 v = UV - 0.5;
		float vig = 1.0 - smoothstep(0.18, 0.5, length(v * vec2(1.0, 1.6)));
		o *= mix(0.55, 1.05, vig);
		alpha = smoothstep(0.0, 0.12, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)) * 3.0);
	} else if (pub == 3) {
		float t = l + (hash(floor(p)) - 0.5) * 0.18;
		float ink = 1.0 - step(0.62, t);
		vec3 paper = vec3(0.95, 0.945, 0.935);
		o = mix(paper, vec3(0.08), ink);
		// one riso colour where it is mid-tone, slightly off register
		float mid = smoothstep(0.55, 0.75, luma(texture(TEXTURE, UV + vec2(2.0, 1.0) * px).rgb)) * (1.0 - smoothstep(0.85, 0.95, l));
		o = mix(o, o * accent.rgb, mid * 0.85);
	} else if (pub == 4) {
		float e = edge(TEXTURE, UV, px);
		vec3 paper = vec3(0.995, 0.995, 1.0);
		o = mix(paper, vec3(0.14, 0.2, 0.32), smoothstep(0.12, 0.3, e));
		o = mix(o, vec3(0.8, 0.86, 0.95), step(l, 0.55) * 0.25 * (1.0 - smoothstep(0.12, 0.3, e)));
	} else {
		float h1 = abs(fract((p.x + p.y) / 4.0) - 0.5);
		float h2 = abs(fract((p.x - p.y) / 4.0) - 0.5);
		float ink = 0.0;
		ink = max(ink, step(l, 0.78) * step(h1, 0.16));
		ink = max(ink, step(l, 0.5) * step(h2, 0.16));
		ink = max(ink, step(l, 0.28));
		float e = edge(TEXTURE, UV, px);
		ink = max(ink, smoothstep(0.2, 0.4, e));
		o = mix(vec3(0.94, 0.87, 0.71), vec3(0.3, 0.18, 0.1), ink);
	}
	COLOR = vec4(o, alpha);
}
