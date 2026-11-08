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
		float cellsz = 2.1;
		vec2 r = vec2(p.x + p.y, p.y - p.x) * 0.7071 / cellsz;
		vec2 f = fract(r) - 0.5;
		float rad = sqrt(1.0 - clamp(l * 1.1 - 0.05, 0.0, 1.0)) * 0.62;
		float ink = 1.0 - smoothstep(rad - 0.08, rad + 0.08, length(f));
		o = mix(vec3(0.9, 0.88, 0.82), vec3(0.1, 0.1, 0.12), ink);
	} else if (pub == 1) {
		// comic print: dots in the shadows
		vec2 f = fract(p / 3.5) - 0.5;
		float shade = step(l, 0.5) * step(0.12, l) * (1.0 - smoothstep(0.16, 0.22, length(f)));
		o = mix(c, c * 0.7, shade);
	} else if (pub == 2) {
		// oil paint: brush smear, canvas grain, soft edges into the cover
		vec2 smear = vec2(hash(floor(p / vec2(5.0, 2.0))) - 0.5, hash(floor(p / vec2(2.0, 5.0)) + 3.1) - 0.5) * px * 2.5;
		o = texture(TEXTURE, UV + smear).rgb;
		o += (hash(floor(p * 0.5)) - 0.5) * 0.05;
		alpha = smoothstep(0.0, 0.12, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)) * 3.0);
	} else if (pub == 3) {
		// photocopy: a hair of mis-registration on the pink
		vec3 shifted = texture(TEXTURE, UV + vec2(1.5, 0.5) * px).rgb;
		o = mix(c, shifted, 0.35);
	} else {
		o = c;
	}
	COLOR = vec4(o, alpha);
}
