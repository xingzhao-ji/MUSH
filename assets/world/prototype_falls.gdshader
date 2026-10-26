shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// West Falls (prototype geology landmark). Ribbon: UV.x across (0..1), UV.y from the lip (0)
// down to the foot (1); streaks travel downward with shimmer_time (frozen under reduced motion),
// edges feather and the sheet spreads lower down. Mist: soft sheets at the foot.
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform bool mist = false;
// Outlet stream: UV.x across (0..1), UV.y along the channel (downstream); COLOR.r = steepness
// of the reach (more foam where it steps down).
uniform bool stream = false;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 3.7) * 0.28 + vnoise(p * 4.1 + 9.1) * 0.14 + vnoise(p * 8.3 + 1.3) * 0.08;
}
void fragment() {
	float t = shimmer_time * shimmer_amount;
	if (stream) {
		float across = abs(UV.x - 0.5) * 2.0;
		float flow = fbm(vec2(UV.x * 4.0, UV.y * 6.0 - t * 0.6));
		float foam = smoothstep(0.55, 0.85, flow) * (0.25 + 0.75 * COLOR.r);
		ALBEDO = mix(vec3(0.16, 0.38, 0.40), vec3(0.88, 0.93, 0.95), foam);
		ALPHA = clamp((0.72 + 0.25 * foam) * (1.0 - smoothstep(0.6, 1.0, across)), 0.0, 1.0);
		ROUGHNESS = 0.15;
		SPECULAR = 0.5;
		EMISSION = vec3(0.02, 0.04, 0.05) * night * foam;
	} else if (mist) {
		vec2 c = (UV - vec2(0.5, 0.55)) * vec2(2.0, 2.4);
		float puff = fbm(UV * 3.0 + vec2(t * 0.02, -t * 0.04));
		ALBEDO = vec3(0.92, 0.94, 0.96);
		ALPHA = (1.0 - smoothstep(0.2, 1.0, length(c))) * (0.5 + 0.5 * puff) * 0.3;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		float across = abs(UV.x - 0.5) * 2.0;
		float flow = fbm(vec2(UV.x * 9.0, UV.y * 14.0 - t * 0.9));
		float fine = fbm(vec2(UV.x * 26.0 + 3.1, UV.y * 40.0 - t * 1.6));
		float streak = smoothstep(0.35, 0.8, flow * 0.65 + fine * 0.45);
		float edge = 1.0 - smoothstep(0.55 - 0.25 * UV.y, 1.0, across);
		ALBEDO = mix(vec3(0.70, 0.80, 0.84), vec3(0.97, 0.98, 0.99), streak);
		ALPHA = clamp(mix(0.5, 0.95, streak) * edge * smoothstep(0.0, 0.03, UV.y), 0.0, 1.0);
		ROUGHNESS = 0.35;
		SPECULAR = 0.4;
		EMISSION = vec3(0.03, 0.04, 0.05) * night * streak;
	}
}
