shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Valley mist pooled at the feet of the West Wall (prototype, visual only): soft vertical sheets
// standing in front of the face. UV.x runs along a sheet, UV.y from its base (0) to its top (1).
// Dense at the base, feathered at the sides and top, broken by slow drifting noise, softened
// where it meets terrain or rock (depth buffer) and faded out near the camera, so a sheet never
// reads as a card. Unshaded: its colour follows the time of day (warm pale by day, blue-violet
// at night, grey in rain). Drift follows shimmer_time, which freezes under reduced motion.
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float strength = 0.55;
// Capture-only diagnosis (0 = final); 4 = flat mask.
uniform int debug_view = 0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
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
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 3.7) * 0.28 + vnoise(p * 4.1 + 9.1) * 0.14 + vnoise(p * 8.3 + 1.3) * 0.08;
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float drift = shimmer_time * 0.006 * shimmer_amount;
	float along = (v_world.x + v_world.z) * 0.008;
	float body = fbm(vec2(along + drift, v_world.y * 0.012 - drift * 0.4));
	float wisps = fbm(vec2(along * 3.1 - drift * 1.7, v_world.y * 0.035 + 2.3));
	float sides = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	float base = pow(1.0 - clamp(UV.y, 0.0, 1.0), 1.8);
	float a = sides * base * smoothstep(0.28, 0.72, body * 0.75 + wisps * 0.35);
	// Soft contact: fade over the last 30 m before the sheet meets the scene behind or below it.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -upos.z / upos.w;
	float frag_z = -VERTEX.z;
	a *= clamp((scene_z - frag_z) / 30.0, 0.0, 1.0);
	// Never a card near the viewer.
	a *= smoothstep(140.0, 320.0, frag_z);
	ALPHA = clamp(a * strength * mix(1.0, 1.3, rain) * mix(1.0, 0.8, night), 0.0, 1.0);
	vec3 day = vec3(0.90, 0.88, 0.93);
	vec3 dusk = vec3(0.24, 0.24, 0.40);
	ALBEDO = mix(mix(day, vec3(0.72, 0.72, 0.76), rain), dusk, night);
	if (debug_view == 4) { ALBEDO = vec3(1.0, 1.0, 0.0); ALPHA = a > 0.02 ? 1.0 : 0.0; }
}
