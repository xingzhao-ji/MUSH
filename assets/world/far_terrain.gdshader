shader_type spatial;
render_mode cull_back;
// Coarse far terrain (kind 0) and lake (kind 1): lit, back-face culled. Presentation
// only, no collision. debug_unlit shows the terrain's own colour with no lighting.
uniform int kind = 0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform bool debug_unlit = false;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
uniform vec3 clearing_green : source_color = vec3(0.44, 0.50, 0.20);
uniform vec3 moss : source_color = vec3(0.28, 0.40, 0.22);
uniform vec3 valley_teal : source_color = vec3(0.10, 0.27, 0.23);
uniform vec3 cliff_ochre : source_color = vec3(0.56, 0.47, 0.38);
uniform vec3 cliff_grey : source_color = vec3(0.40, 0.38, 0.40);
uniform vec3 sand : source_color = vec3(0.62, 0.54, 0.42);
uniform vec3 water_deep : source_color = vec3(0.05, 0.13, 0.17);
uniform vec3 sky_tint : source_color = vec3(0.75, 0.62, 0.85);
varying vec3 v_world;

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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 albedo;
	vec3 emit = vec3(0.0);
	float rough = 0.95;
	float spec = 0.05;
	if (kind == 0) {
		float h = v_world.y;
		float fine = fbm(v_world.xz * 0.3);
		float steep = 1.0 - clamp(nw.y, 0.0, 1.0);
		float band = fbm(vec2((v_world.x + v_world.z) * 0.25, h * 0.04));
		float stripe = 0.5 + 0.5 * sin(h * 0.45 + band * 5.0);
		vec3 upper = mix(clearing_green, moss, smoothstep(2.0, 60.0, h + 70.0 * smoothstep(-20.0, -60.0, h)));
		vec3 floor_col = mix(upper, valley_teal, smoothstep(-25.0, -60.0, h));
		vec3 cliff = mix(cliff_grey, cliff_ochre, stripe * 0.8 + 0.2 * band);
		albedo = mix(floor_col, cliff, smoothstep(0.30, 0.55, steep));
		albedo = mix(albedo, sand, smoothstep(-70.0, -73.0, h) * smoothstep(-80.0, -73.0, h) * 0.7);
		albedo *= 0.82 + 0.36 * fine;
	} else {
		float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
		albedo = water_deep;
		emit = sky_tint * (0.12 + 0.45 * f) * mix(1.0, 0.25, night);
		rough = 0.06;
		spec = 0.7;
	}
	if (debug_unlit) {
		EMISSION = albedo;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = albedo;
		EMISSION = emit;
	}
	ROUGHNESS = rough;
	SPECULAR = spec;
}
