shader_type spatial;
render_mode cull_back;
// Far fungal canopies, stems, rock pillars/boulders and forest carpet. Lit with real
// sun/ambient/fog. mode: 0 cap, 1 stem, 2 rock, 5 forest clump (instance COLOR is
// its albedo). UV.x = angle, UV.y = profile parameter. Presentation only.
uniform int mode = 0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
uniform vec3 amber : source_color = vec3(1.0, 0.55, 0.24);
uniform vec3 lavender : source_color = vec3(0.56, 0.45, 0.86);
uniform vec3 deep : source_color = vec3(0.20, 0.15, 0.40);
varying float v_tint;
varying vec3 v_col;

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
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}
void vertex() {
	v_tint = COLOR.r;
	v_col = COLOR.rgb;
}
void fragment() {
	float glow = mix(1.0, 1.9, night) * mix(1.0, 0.7, rain);
	float pulse = 1.0 + shimmer_amount * 0.04 * sin(shimmer_time * 0.5 + v_tint * 20.0);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sun_side = clamp(dot(nw, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 albedo = vec3(0.5);
	vec3 emit = vec3(0.0);
	float rough = 0.8;
	float spec = 0.2;
	if (mode == 0) {
		float a = UV.x * 6.2831853;
		if (UV.y < 0.5) {
			// Flat dome: violet flesh, soft growth bands, sun-lit upturned rim.
			float s = UV.y * 2.0;
			float mottle = fbm(vec2(UV.x * 14.0, s * 5.0));
			float band = 0.5 + 0.5 * sin(s * 20.0 + mottle * 4.0);
			albedo = mix(deep * 1.2, lavender * 0.9, 0.25 + 0.5 * mottle) * (0.92 + 0.08 * band * aa(s * 20.0));
			emit = amber * smoothstep(0.8, 1.0, s) * (0.25 + 0.5 * sun_side) * glow * pulse;
			rough = 0.55;
		} else {
			// Underside: warm gill glow strongest near the stem, with thin branching veins
			// over it (no hard dark bands between them).
			float t = (UV.y - 0.5) * 2.0;
			float warp = vnoise(vec2(UV.x * 30.0, t * 5.0)) * 3.5;
			float vp = a * 28.0 + warp * (1.0 - t * 0.5);
			float vein = pow(0.5 + 0.5 * sin(vp), 28.0) * aa(vp);
			float branch = pow(0.5 + 0.5 * sin(a * 70.0 + warp * 2.0 + t * 12.0), 30.0) * aa(a * 70.0) * smoothstep(0.3, 0.8, t);
			float gill = mix(0.5, 0.5 + 0.5 * sin(a * 160.0), aa(a * 160.0));
			albedo = mix(lavender * 0.75, vec3(0.78, 0.60, 0.62), 0.4 + 0.3 * t) * (0.85 + 0.15 * gill);
			emit = amber * (0.10 + 0.30 * smoothstep(0.35, 1.0, t) + vein * 0.45 + branch * 0.30) * glow * pulse;
			rough = 0.85;
		}
		albedo *= 0.9 + 0.2 * v_tint;
	} else if (mode == 1) {
		float n = fbm(vec2(UV.x * 10.0, UV.y * 16.0));
		albedo = mix(deep * 0.9, lavender * 0.4, 0.2 + 0.35 * n);
		albedo *= 0.55 + 0.45 * smoothstep(0.0, 0.7, UV.y);
		emit = amber * smoothstep(0.8, 1.0, UV.y) * 0.25 * glow;
		rough = 0.9;
	} else if (mode == 2) {
		float n = fbm(vec2(UV.x * 12.0, UV.y * 14.0));
		float strata = 0.5 + 0.5 * sin(UV.y * 26.0 + n * 3.0);
		albedo = mix(vec3(0.34, 0.30, 0.34), vec3(0.50, 0.42, 0.38), strata * 0.6 + 0.2 * n) * (0.9 + 0.2 * v_tint);
		rough = 0.95;
		spec = 0.08;
	} else {
		// Forest clump: foliage palette in instance COLOR, darker toward the base.
		albedo = v_col * (0.55 + 0.5 * UV.y) * (0.85 + 0.3 * sun_side);
		rough = 0.9;
		spec = 0.05;
	}
	ALBEDO = albedo;
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
