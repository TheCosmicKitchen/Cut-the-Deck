// Shared signed-distance helpers. Distances are in pixels; negative is inside.
float sd_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// coverage of a shape edge, anti-aliased over about one pixel
float fill_aa(float d) {
	return clamp(0.5 - d / max(fwidth(d), 0.0001), 0.0, 1.0);
}
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
