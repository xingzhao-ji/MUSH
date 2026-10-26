shader_type spatial;
render_mode cull_back;
// Far fungal canopies, stems, rock pillars/boulders and forest carpet, lit by the real
// sun/ambient/fog. mode: 0 cap, 1 stem, 2 rock, 5 forest clump (instance COLOR is its
// albedo). UV.x = angle, UV.y = profile parameter. Presentation only, no collision.
uniform int mode = 0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 moss_mean : source_color = vec3(0.30, 0.36, 0.18);
uniform vec3 amber : source_color = vec3(1.0, 0.62, 0.30);
uniform vec3 flesh : source_color = vec3(0.70, 0.52, 0.72);
uniform vec3 flesh_rim : source_color = vec3(0.88, 0.62, 0.66);
uniform vec3 gill : source_color = vec3(0.86, 0.70, 0.66);
uniform vec3 stem_bark : source_color = vec3(0.47, 0.41, 0.47);
varying float v_tint;
varying float v_cavity;
varying vec3 v_col;
varying vec3 v_world;
varying vec3 v_normal;

float aa(float phase) {
	return 1.0 - smoothstep(0.35, 1.2, fwidth(phase));
}
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
// Soft round spots (cell-noise distance), for cap freckles and luminous dots.
float spots(vec2 p, float size) {
	vec2 i = floor(p);
	float best = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = i + vec2(float(x), float(y));
			vec2 centre = cell + vec2(hash21(cell), hash21(cell + 7.1));
			best = min(best, length(p - centre));
		}
	}
	return 1.0 - smoothstep(size * 0.6, size, best);
}
void vertex() {
	v_tint = COLOR.r;
	v_cavity = COLOR.g;
	v_col = COLOR.rgb;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float glow = mix(1.0, 2.0, night) * mix(1.0, 0.75, rain);
	float pulse = 1.0 + shimmer_amount * 0.03 * sin(shimmer_time * 0.4 + v_tint * 20.0);
	vec3 n = normalize(v_normal);
	float sun_side = clamp(dot(n, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 albedo = vec3(0.5);
	vec3 emit = vec3(0.0);
	float rough = 0.8;
	float spec = 0.2;
	if (mode == 0) {
		float a = UV.x * 6.2831853;
		if (UV.y < 0.5) {
			// Fleshy dome: soft mottling, pale freckles, warmer toward the rounded rim.
			float s = UV.y * 2.0;
			vec2 skin = vec2(UV.x * 40.0, s * 9.0);
			float mottle = fbm(skin * 0.6 + v_tint * 13.0);
			albedo = mix(flesh, flesh_rim, smoothstep(0.55, 1.0, s) * 0.8 + 0.2 * mottle) * (0.82 + 0.3 * mottle);
			float freckle = spots(skin, 0.32) * aa(skin.x);
			albedo = mix(albedo, vec3(0.94, 0.86, 0.90), freckle * 0.45 * smoothstep(0.1, 0.8, s));
			emit = amber * freckle * 0.10 * glow * (1.0 - s * 0.5) + flesh_rim * smoothstep(0.88, 1.0, s) * 0.10 * glow;
			rough = 0.6;
		} else {
			// Underside: many fine, slightly wandering gills (anti-aliased to an even tone at
			// distance) with a soft warm glow gathered toward the stem. No radial stripes.
			float t = (UV.y - 0.5) * 2.0;
			float wander = fbm(vec2(UV.x * 12.0, t * 3.0)) * 2.0;
			float gp = a * 180.0 + wander;
			float lines = mix(0.5, 0.5 + 0.5 * sin(gp), aa(gp));
			float fork = mix(0.5, 0.5 + 0.5 * sin(a * 360.0 + wander * 2.0), aa(a * 360.0)) * smoothstep(0.0, 0.5, t);
			albedo = gill * (0.72 + 0.22 * lines + 0.10 * fork) * (0.85 + 0.2 * fbm(vec2(UV.x * 30.0, t * 8.0)));
			float core = smoothstep(0.45, 1.0, t);
			emit = amber * (0.06 + 0.42 * core * core + 0.05 * lines * core) * glow * pulse;
			emit += amber * spots(vec2(UV.x * 90.0, t * 14.0), 0.22) * 0.25 * glow * (0.3 + core);
			rough = 0.85;
		}
	} else if (mode == 1) {
		// Stem and roots: tone read at distance from large patches, long streaks and the
		// fused-strand grooves (vertex G); fine grain only adds near detail.
		float macro = fbm(vec2(UV.x * 4.0, UV.y * 2.2) + v_tint * 7.0);
		float streak = fbm(vec2(UV.x * 14.0, UV.y * 0.8));
		float grain = fbm(vec2(UV.x * 60.0, UV.y * 4.0));
		vec3 dark = stem_bark * 0.5;
		vec3 light = vec3(0.70, 0.60, 0.62);
		albedo = mix(dark, light, clamp(v_cavity * 0.65 + macro * 0.4 + streak * 0.2 - 0.12, 0.0, 1.0));
		albedo *= (0.72 + 0.32 * smoothstep(0.0, 0.6, UV.y)) * (0.92 + 0.12 * grain);
		float moss_line = smoothstep(0.24, 0.03, UV.y + (fbm(vec2(UV.x * 20.0, 1.0)) - 0.5) * 0.08);
		albedo = mix(albedo, moss_mean * 1.25, moss_line * 0.8);
		float collar = smoothstep(0.86, 1.0, UV.y);
		emit = amber * collar * 0.24 * glow;
		emit += amber * spots(vec2(UV.x * 50.0, UV.y * 30.0), 0.25) * (1.0 - v_cavity) * smoothstep(0.3, 0.9, UV.y) * 0.10 * glow;
		rough = 0.9;
	} else if (mode == 2) {
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		float scale = 0.12;
		vec3 rock = texture(rock_tex, v_world.zy * scale).rgb * w.x + texture(rock_tex, v_world.xz * scale).rgb * w.y + texture(rock_tex, v_world.xy * scale).rgb * w.z;
		float streak = fbm(vec2((v_world.x + v_world.z) * 0.05, v_world.y * 0.01));
		albedo = rock * mix(vec3(0.95, 0.88, 0.86), vec3(1.25, 1.08, 0.92), streak) * (0.9 + 0.2 * v_tint);
		albedo = mix(albedo, moss_mean, smoothstep(0.7, 0.95, n.y) * 0.6);
		rough = 0.92;
		spec = 0.1;
	} else {
		// Distant forest clump: foliage palette in instance COLOR, darker toward the base.
		albedo = v_col * 0.72 * (0.5 + 0.55 * UV.y) * (0.85 + 0.3 * sun_side) * (0.85 + 0.3 * fbm(v_world.xz * 0.15));
		rough = 0.9;
		spec = 0.05;
	}
	ALBEDO = albedo;
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
