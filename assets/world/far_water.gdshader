shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
// Lake surface: depth-tinted teal (shallow shore to deep basin), two drifting ripple
// normal layers and a restrained horizon reflection. No flat emissive sheet.
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 shallow : source_color = vec3(0.22, 0.42, 0.40);
uniform vec3 deep : source_color = vec3(0.02, 0.10, 0.13);
uniform vec3 horizon : source_color = vec3(0.86, 0.66, 0.62);
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform bool debug_unlit = false;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
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
float ripples(vec2 p) {
	float t = shimmer_time * shimmer_amount;
	return vnoise(p * 0.35 + vec2(t * 0.05, t * 0.03)) * 0.6 + vnoise(p * 0.9 - vec2(t * 0.07, -t * 0.04)) * 0.4;
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	view.xyz /= view.w;
	float thickness = max(0.0, -view.z - (-VERTEX.z));
	float depth_mix = smoothstep(0.0, 18.0, thickness);
	vec3 water = mix(shallow, deep, depth_mix);
	water = mix(water, water * vec3(0.55, 0.62, 0.85), night);
	// Ripple normal from finite differences of the ripple field.
	vec2 p = v_world.xz;
	float e = 0.6;
	float c = ripples(p);
	vec3 slope = vec3(ripples(p + vec2(e, 0.0)) - c, 0.0, ripples(p + vec2(0.0, e)) - c) * mix(0.35, 0.6, rain);
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 reflection = horizon * mix(1.0, 0.18, night) * mix(1.0, 0.6, rain);
	if (debug_unlit) {
		EMISSION = water;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = water;
		EMISSION = reflection * fresnel * 0.22;
	}
	ALPHA = mix(0.62, 0.97, depth_mix) + fresnel * 0.03;
	ROUGHNESS = 0.26;
	SPECULAR = 0.14;
}
