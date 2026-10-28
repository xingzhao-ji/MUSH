shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Concept-1 far backdrop (prototype, visual only): a vast curved haze card beyond the valley's islands, in front of
// the basin's far wall, painting what design-reference/mush-concept-1.png shows there: a peach-pink sunset band over
// lavender mist, cloud banks, and the faint silhouettes of distant rock spires and umbrella mushrooms, under a violet
// sky. UV.x runs along the arc (0 left .. 1 right as seen from the vista), UV.y from the foot (0) to the top (1).
// Faded out for a camera low in the basin (it only reads as distance from the cliff tops) and at night/rain.
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float strength = 1.0;
uniform float glow_u = 0.42;
uniform float min_camera_y = 10.0;
// Capture c1v18: the first colours washed out to lilac-white; deeper peach, mauve and violet as in the concept.
uniform vec3 sky_top : source_color = vec3(0.34, 0.35, 0.66);
uniform vec3 sky_mid : source_color = vec3(0.69, 0.48, 0.72);
uniform vec3 horizon : source_color = vec3(0.96, 0.66, 0.53);
uniform vec3 mist : source_color = vec3(0.66, 0.63, 0.82);
uniform vec3 far_rock : source_color = vec3(0.50, 0.44, 0.63);

float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 3.7) * 0.28 + vnoise(p * 4.1 + 9.1) * 0.14 + vnoise(p * 8.3 + 1.3) * 0.08;
}
// Skyline height (in UV.y) of distant spires and mushroom crowns at u.
float skyline(float u, float scale, float seed) {
	float x = u * scale;
	float i = floor(x), f = fract(x);
	float h = 0.0;
	for (int k = -1; k <= 1; k++) {
		float c = i + float(k);
		float r = hash11(c * 1.7 + seed);
		float w = 0.18 + 0.25 * hash11(c * 3.1 + seed);
		float d = abs(f - float(k) - 0.5) / w;
		float spire = (1.0 - smoothstep(0.0, 1.0, d)) * (0.05 + 0.12 * r * r);
		float cap = (r > 0.82) ? (1.0 - smoothstep(0.7, 1.6, d)) * 0.03 : 0.0;
		h = max(h, spire + cap);
	}
	return h;
}
void fragment() {
	float u = UV.x, v = UV.y;
	float drift = shimmer_time * 0.002 * shimmer_amount;
	float g = exp(-pow((u - glow_u) / 0.22, 2.0));
	// sky: violet top, pink-lilac middle, peach band toward the glow at the horizon
	vec3 col = mix(sky_mid, sky_top, smoothstep(0.42, 0.95, v));
	col = mix(col, horizon, (1.0 - smoothstep(0.18, 0.5, v)) * (0.55 + 0.45 * g));
	// cloud banks: bright crowns toward the glow, lilac shadows
	float cl = fbm(vec2(u * 7.0 + drift, v * 9.0));
	float band = smoothstep(0.25, 0.45, v) * (1.0 - smoothstep(0.62, 0.8, v));
	float cloud = smoothstep(0.5, 0.75, cl) * band;
	col = mix(col, mix(vec3(0.72, 0.62, 0.80), vec3(1.0, 0.86, 0.78), 0.4 + 0.6 * g), cloud * 0.75);
	// distant spires and mushroom crowns, two hazy layers
	float far1 = 0.2 + skyline(u, 26.0, 3.0);
	float far2 = 0.14 + skyline(u, 15.0, 9.0) * 1.3;
	if (v < far1) col = mix(col, mix(far_rock, horizon, 0.55), 0.55);
	if (v < far2) col = mix(col, far_rock, 0.7);
	// distant umbrella mushrooms (concept: hazy glowing caps above the far spires)
	for (int m = 0; m < 3; m++) {
		float mu = float[](0.36, 0.57, 0.83)[m];
		float cw = float[](0.05, 0.035, 0.045)[m];
		float cy = float[](0.36, 0.3, 0.4)[m];
		float dx = (u - mu) / cw;
		float capv = cy + 0.035 * sqrt(max(0.0, 1.0 - dx * dx));
		bool in_cap = abs(dx) < 1.0 && v < capv && v > cy - 0.006;
		bool in_stem = abs(u - mu) < cw * 0.09 && v < cy;
		if (in_cap || in_stem) col = mix(col, mix(far_rock, sky_mid, 0.35), 0.75);
		if (abs(dx) < 1.0 && abs(v - (cy - 0.003)) < 0.004) col = mix(col, horizon * 1.15, 0.8);
	}
	// mist at the foot
	col = mix(col, mist, 1.0 - smoothstep(0.02, 0.2, v + 0.04 * fbm(vec2(u * 12.0 - drift, 2.0))));
	float a = strength * smoothstep(0.0, 0.08, v) * smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.94, u);
	a *= smoothstep(min_camera_y - 30.0, min_camera_y + 30.0, CAMERA_POSITION_WORLD.y);
	a *= 1.0 - 0.6 * rain;
	// night: the same layout in deep blue-violet, the horizon a faint dusk line
	vec3 night_col = mix(vec3(0.06, 0.06, 0.14), vec3(0.14, 0.13, 0.26), 1.0 - smoothstep(0.1, 0.6, v));
	if (v < far2) night_col *= 0.7;
	col = mix(mix(col, vec3(0.62, 0.62, 0.68), rain), night_col, night);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
