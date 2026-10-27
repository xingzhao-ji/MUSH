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
// Mode 2 rock brightness (1.6 = the spires and rim boulders); the meadow erratics use less, and
// moss_cover > 0 adds lichen-moss on their upper faces and a damp, darker foot.
uniform float rock_gain = 1.6;
uniform float moss_cover = 0.0;
// Hero stem organic finish, only within stem_focus (x, z, radius) of the hero base; at zero
// strength every stem renders exactly as before. Matte, soft tonal modulation at several
// metres, very low-contrast fibre that fades with distance, gentle two-scale normal undulation
// and a soil/moss blend where the root meets the ground.
// Hero cap craft (set only on the HeroCanopy material; 0 = exact previous look): organic tone
// zones, margin fibrils and shaded warts on the dome; readable wandering gill bundles with
// shadowed gaps, a cool lilac underside with the warm glow kept near the stem, and sparse broken
// luminous veins (faint by day, stronger at night).
uniform float cap_craft = 0.0;
uniform vec4 stem_focus = vec4(0.0);
uniform float stem_organic = 0.0;
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
			if (cap_craft > 0.0) {
				// Structure only, on the cap's own colours (hue identity kept): broad tone zones,
				// fine distance-faded fibrils toward the margin, and a soft shaded edge round each wart.
				float zone = fbm(vec2(UV.x * 14.0, s * 5.0) + v_tint * 7.0 + 2.3);
				float fine = mix(0.5, fbm(vec2(UV.x * 70.0, s * 22.0) + 5.1), aa(UV.x * 70.0));
				vec3 base = albedo * mix(0.84, 1.14, zone) * mix(0.94, 1.05, fine);
				float fp = a * 480.0 + fbm(vec2(UV.x * 18.0, s * 4.0)) * 4.0;
				base *= 1.0 - 0.07 * mix(0.5, 0.5 + 0.5 * sin(fp), aa(fp)) * smoothstep(0.5, 0.95, s);
				float wart_edge = clamp(spots(skin, 0.44) - spots(skin, 0.32), 0.0, 1.0) * aa(skin.x);
				base *= 1.0 - 0.15 * wart_edge * smoothstep(0.08, 0.7, s);
				albedo = mix(albedo, base, cap_craft);
				emit += flesh_rim * smoothstep(0.9, 1.0, s) * 0.06 * glow * cap_craft;
			}
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
			if (cap_craft > 0.0) {
				// Gill bundles (wandering, varied width) and plates; shadowed gaps deepen toward the margin.
				// Irregular bundles: the angle is warped by low-frequency noise (several bundle widths)
				// and each bundle gets its own brightness, so the underside never reads as an even fan.
				float warp = (fbm(vec2(UV.x * 5.0, 0.37)) - 0.5) * 9.0 + (fbm(vec2(UV.x * 16.0, t * 2.0) + 1.7) - 0.5) * 3.0;
				float bundle_p = a * 48.0 + warp;
				float bundle = mix(0.5, 0.5 + 0.5 * sin(bundle_p), aa(bundle_p));
				float bundle_tone = 0.86 + 0.28 * hash21(vec2(floor(bundle_p / 6.2831853), 3.1));
				float plate_p = a * 180.0 + warp * 3.7;
				float plate = mix(0.5, 0.5 + 0.5 * sin(plate_p), aa(plate_p));
				// Gaps deepen toward the margin, easing off in the outermost rim strip.
				float deep = smoothstep(1.0, 0.15, t) * smoothstep(0.0, 0.08, t);
				float shade = (1.0 - deep * (0.26 * (1.0 - bundle) + 0.16 * (1.0 - plate))) * mix(1.0, bundle_tone, deep);
				vec3 flesh_under = mix(vec3(0.62, 0.56, 0.80), gill, smoothstep(0.65, 1.0, t));
				vec3 under = flesh_under * shade * (0.88 + 0.18 * fbm(vec2(UV.x * 30.0, t * 8.0)));
				// The rim lip shares t = 0 with the underside's edge; its outward-facing surface keeps
				// the cap's own colour so the silhouette band is unchanged.
				float lip = smoothstep(-0.8, -0.4, n.y) * (1.0 - smoothstep(0.0, 0.04, t));
				albedo = mix(albedo, under, cap_craft * (1.0 - lip));
				// Warm glow kept toward the stem; sparse, broken luminous veins along a few gills.
				emit = mix(emit, emit * (0.45 + 0.55 * core), cap_craft);
				float vein_p = a * 24.0 + fbm(vec2(UV.x * 6.0, t * 3.0) + 9.2) * 4.0;
				float vein = pow(mix(0.5, 0.5 + 0.5 * sin(vein_p), aa(vein_p)), 8.0) * smoothstep(0.1, 0.7, t);
				vein *= smoothstep(0.4, 0.62, fbm(vec2(UV.x * 24.0, t * 6.0) + 3.3));
				emit += mix(amber, vec3(0.85, 0.62, 1.0), 0.5) * vein * (0.05 + 0.25 * night) * glow * cap_craft;
			}
		}
	} else if (mode == 1) {
		// Stem: broad tonal patches and groove/buttress-valley shading carry the form at
		// distance; a soft vertical fibre adds texture near and fades out far (no stripes).
		float macro = fbm(vec2(UV.x * 3.0, UV.y * 1.6) + v_tint * 7.0);
		float fibre = mix(0.5, fbm(vec2(UV.x * 26.0, UV.y * 1.2)), aa(UV.x * 26.0));
		float grain = mix(0.5, fbm(vec2(UV.x * 70.0, UV.y * 5.0)), aa(UV.x * 70.0));
		vec3 dark = stem_bark * 0.45;
		vec3 light = vec3(0.66, 0.56, 0.54);
		albedo = mix(dark, light, clamp(v_cavity * 0.7 + macro * 0.35 - 0.08, 0.0, 1.0));
		albedo *= (0.9 + 0.14 * fibre) * (0.95 + 0.08 * grain);
		albedo *= 0.68 + 0.36 * smoothstep(0.0, 0.5, UV.y);
		float moss_line = smoothstep(0.24, 0.05, UV.y + (fbm(vec2(UV.x * 8.0, 1.0)) - 0.5) * 0.10);
		albedo = mix(albedo, moss_mean * 1.2, moss_line * 0.75);
		float collar = smoothstep(0.86, 1.0, UV.y);
		emit = amber * collar * 0.24 * glow;
		emit += amber * spots(vec2(UV.x * 50.0, UV.y * 30.0), 0.25) * (1.0 - v_cavity) * smoothstep(0.3, 0.9, UV.y) * 0.08 * glow;
		rough = 0.96;
		spec = 0.06;
		float hero_w = 0.0;
		if (stem_organic > 0.0 && stem_focus.z > 0.0) hero_w = stem_organic * (1.0 - smoothstep(stem_focus.z * 0.8, stem_focus.z, length(v_world.xz - stem_focus.xy)));
		if (hero_w > 0.0) {
			float patchy = fbm(v_world.xz * 0.06 + vec2(v_world.y * 0.03));
			// Patches roughly as tall as they are wide on the stem (no vertical bands).
			float drift = fbm(vec2(UV.x * 9.0, v_world.y * 0.045) + 3.1);
			vec3 tone = mix(vec3(0.86, 0.82, 0.80), vec3(1.08, 1.01, 0.92), patchy) * mix(0.93, 1.04, drift);
			float fine = mix(0.5, fbm(vec2(UV.x * 140.0, UV.y * 2.0)), aa(UV.x * 140.0));
			tone *= 0.97 + 0.06 * fine;
			float soil = 1.0 - smoothstep(0.0, 0.10, UV.y + (fbm(vec2(UV.x * 12.0, 2.0)) - 0.5) * 0.06);
			vec3 organic = albedo * tone;
			organic = mix(organic, mix(vec3(0.30, 0.25, 0.19), moss_mean, 0.35), soil * 0.7);
			albedo = mix(albedo, organic, hero_w);
			rough = mix(rough, 1.0, hero_w);
			spec = mix(spec, 0.02, hero_w);
			vec3 swell = vec3(fbm(v_world.zy * 0.08) - 0.5, 0.0, fbm(v_world.xy * 0.08 + 5.0) - 0.5);
			vec3 velvet = vec3(fbm(v_world.zy * 0.35 + 2.0) - 0.5, 0.0, fbm(v_world.xy * 0.35 + 9.0) - 0.5);
			NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + (swell * 0.14 + velvet * 0.10) * hero_w), 0.0)).xyz);
		}
	} else if (mode == 2) {
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		float scale = 0.12;
		vec3 rock = texture(rock_tex, v_world.zy * scale).rgb * w.x + texture(rock_tex, v_world.xz * scale).rgb * w.y + texture(rock_tex, v_world.xy * scale).rgb * w.z;
		vec3 broad = texture(rock_tex, v_world.zy * scale * 0.25 + 0.31).rgb * w.x + texture(rock_tex, v_world.xz * scale * 0.25 + 0.57).rgb * w.y + texture(rock_tex, v_world.xy * scale * 0.25 + 0.13).rgb * w.z;
		rock = rock * mix(vec3(1.0), broad * 2.0, 0.5);
		float streak = fbm(vec2((v_world.x + v_world.z) * 0.05, v_world.y * 0.01));
		float strata = fbm(vec2(v_world.y * 0.05 + fbm(v_world.xz * 0.01) * 1.4, 0.61));
		// Granite family (the West Wall's grey stone): neutral, lighter, faint strata only. The
		// warm streak x strata product on the dark brown texture read as striped termite mounds.
		vec3 base = rock * mix(vec3(0.95, 0.92, 0.9), vec3(1.15, 1.08, 1.0), streak) * mix(0.92, 1.05, strata) * (0.9 + 0.2 * v_tint);
		float g = dot(base, vec3(0.299, 0.587, 0.114));
		albedo = mix(base, vec3(g) * vec3(1.0, 1.0, 1.03), 0.65) * rock_gain;
		albedo = mix(albedo, moss_mean, smoothstep(0.7, 0.95, n.y) * 0.6);
		if (moss_cover > 0.0) {
			float patch = smoothstep(0.42, 0.62, fbm(v_world.xz * 0.35 + v_world.y * 0.2));
			albedo = mix(albedo, moss_mean * mix(0.8, 1.1, fbm(v_world.xz * 1.3)), smoothstep(0.15, 0.6, n.y) * patch * moss_cover);
			albedo *= mix(1.0, 0.6, (1.0 - smoothstep(-0.4, 0.2, n.y)) * moss_cover);
		}
		rough = 0.92;
		spec = 0.1;
	} else {
		// Distant forest clump: foliage palette in instance COLOR, darker toward the base.
		// Deeper, varied forest: the uniform pale-lime crowns read as cotton balls. Darker bases (crown
		// self-shadow), lower overall value, and a slow regional drift between warm yellow-green and
		// cool blue-green stands so the carpet is not one hue.
		vec3 drift = mix(vec3(1.06, 1.0, 0.82), vec3(0.82, 0.95, 1.06), smoothstep(0.3, 0.7, fbm(v_world.xz * 0.006 + 4.1)));
		albedo = v_col * 0.78 * drift * (0.3 + 0.75 * UV.y * UV.y) * (0.85 + 0.3 * sun_side) * (0.8 + 0.4 * fbm(v_world.xz * 0.15));
		rough = 0.9;
		spec = 0.05;
	}
	ALBEDO = albedo;
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
