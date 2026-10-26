shader_type spatial;
render_mode cull_disabled;
// Distant fungal canopies, stems, rock spires, coarse terrain and lake: real lit
// materials (sun, ambient and fog). mode: 0 cap, 1 stem, 2 spire, 3 terrain, 4 lake.
// UV.x = angle, UV.y = profile parameter. Presentation only; no collision.
uniform int mode = 0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform vec3 amber : source_color = vec3(1.0, 0.55, 0.24);
uniform vec3 lavender : source_color = vec3(0.56, 0.45, 0.86);
uniform vec3 deep : source_color = vec3(0.20, 0.15, 0.40);
uniform vec3 sky_tint : source_color = vec3(0.75, 0.62, 0.85);
varying float v_tint;
varying vec3 v_world;

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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float glow = mix(1.0, 1.9, night) * mix(1.0, 0.7, rain);
	float pulse = 1.0 + shimmer_amount * 0.04 * sin(shimmer_time * 0.5 + v_tint * 20.0);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 albedo = vec3(0.5);
	vec3 emit = vec3(0.0);
	float rough = 0.8;
	float spec = 0.25;
	if (mode == 0) {
		float a = UV.x * 6.2831853;
		if (UV.y < 0.5) {
			// Dome: violet flesh, soft growth bands, a thin amber glow at the rim.
			float s = UV.y * 2.0;
			float mottle = fbm(vec2(UV.x * 14.0, s * 5.0));
			float band = 0.5 + 0.5 * sin(s * 20.0 + mottle * 4.0);
			albedo = mix(deep * 1.2, lavender * 0.9, 0.25 + 0.5 * mottle) * (0.92 + 0.08 * band * aa(s * 20.0));
			emit = amber * smoothstep(0.8, 1.0, s) * 0.35 * glow * pulse;
			rough = 0.55;
		} else {
			// Underside: irregular gills with warmth gathered toward the stem.
			float t = (UV.y - 0.5) * 2.0;
			float warp = vnoise(vec2(UV.x * 38.0, t * 4.0)) * 3.0;
			float gp = a * 52.0 + warp;
			float gill = mix(0.5, 0.5 + 0.5 * sin(gp), aa(gp));
			albedo = mix(deep * 1.1, lavender * 0.7, 0.3 + 0.3 * (1.0 - t)) * (0.7 + 0.5 * gill);
			emit = amber * (smoothstep(0.3, 1.0, t) * 0.5 + (1.0 - t) * 0.1) * glow * pulse * (0.75 + 0.35 * gill);
			rough = 0.85;
		}
		albedo *= 0.9 + 0.2 * v_tint;
	} else if (mode == 1) {
		float n = fbm(vec2(UV.x * 10.0, UV.y * 16.0));
		albedo = mix(deep * 1.3, lavender * 0.75, 0.3 + 0.4 * n);
		emit = amber * smoothstep(0.75, 1.0, UV.y) * 0.18 * glow;
		rough = 0.9;
	} else if (mode == 2) {
		float n = fbm(vec2(UV.x * 12.0, UV.y * 14.0));
		float strata = 0.5 + 0.5 * sin(UV.y * 30.0 + n * 3.0);
		albedo = mix(deep * 1.4, lavender * 0.7, 0.25 + 0.35 * n) * (0.9 + 0.12 * strata);
		rough = 0.95;
		spec = 0.1;
	} else if (mode == 3) {
		float h = v_world.y;
		float r = length(v_world.xz);
		float broad = fbm(v_world.xz * 0.004);
		float fine = fbm(v_world.xz * 0.05);
		vec3 clearing = vec3(0.16, 0.25, 0.13);
		vec3 meadow = vec3(0.26, 0.40, 0.27);
		vec3 moss = vec3(0.30, 0.36, 0.34);
		vec3 rock = vec3(0.40, 0.36, 0.50);
		vec3 sand = vec3(0.62, 0.52, 0.42);
		albedo = mix(meadow, moss, clamp(smoothstep(0.0, 60.0, h) * 0.8 + 0.4 * broad, 0.0, 1.0));
		albedo = mix(clearing, albedo, smoothstep(70.0, 320.0, r));
		float steep = 1.0 - clamp(nw.y, 0.0, 1.0);
		albedo = mix(albedo, rock, clamp(smoothstep(60.0, 150.0, h) + steep * 1.8, 0.0, 1.0));
		albedo = mix(albedo, sand, smoothstep(-2.0, -8.5, h) * smoothstep(-14.0, -8.5, h) * 0.8);
		albedo *= 0.85 + 0.3 * fine;
		rough = 0.95;
		spec = 0.05;
	} else {
		float f = pow(1.0 - facing, 3.0);
		albedo = deep * 0.5;
		emit = sky_tint * (0.15 + 0.5 * f) * mix(1.0, 0.25, night) + amber * 0.04 * (1.0 - night);
		rough = 0.08;
		spec = 0.7;
	}
	ALBEDO = albedo;
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
