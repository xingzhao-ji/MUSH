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
// Free-floating C1 cloud banks need a soft lower edge; grounded mist keeps its existing profile.
uniform float bottom_feather = 0.0;
// Spray plume look (0 = valley mist): darker overall tone so it never clips above the sky, and
// billow shading from the drifting noise so it is not a flat white card.
uniform float billow = 0.0;
// Gap strength (0 = solid bank).
uniform float holes = 0.0;
// Day colour, and the colour it takes looking toward the glow (equal = previous look): the
// paintover target (Gemini, vista) has warm mist (hue ~24, L*58) toward the light.
uniform vec3 day_tint : source_color = vec3(0.80, 0.78, 0.93);
uniform vec3 glow_tint : source_color = vec3(0.80, 0.78, 0.93);
uniform vec3 glow_dir = vec3(0.0, 0.0, -1.0);
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
	base *= mix(1.0, smoothstep(0.0, 0.24, UV.y), bottom_feather);
	float a = sides * base * smoothstep(0.28, 0.72, body * 0.75 + wisps * 0.35);
	// Holes: large slow gaps so a bank reads as layered mist with breaks, not a flat sheet (review 05).
	a *= mix(1.0, smoothstep(0.32, 0.62, fbm(vec2(along * 0.45 + 5.1 - drift * 0.6, v_world.y * 0.006 + 1.7))), holes);
	// Soft contact: fade over the last 30 m before the sheet meets the scene behind or below it.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -upos.z / upos.w;
	float frag_z = -VERTEX.z;
	a *= clamp((scene_z - frag_z) / 30.0, 0.0, 1.0);
	// Never a card near the viewer.
	a *= smoothstep(140.0, 320.0, frag_z);
	ALPHA = clamp(a * strength * mix(1.0, 1.3, rain) * mix(1.0, 0.8, night), 0.0, 1.0);
	// Lavender in shade (concepts: mist hue ~237-270, saturation ~0.2); it was near-grey (sat 0.03-0.08).
	vec3 to_frag = normalize(v_world - CAMERA_POSITION_WORLD);
	float toward = smoothstep(-0.2, 0.9, dot(normalize(to_frag.xz + vec2(1e-5)), normalize(glow_dir.xz + vec2(1e-5))));
	vec3 day = mix(day_tint, glow_tint, toward);
	vec3 dusk = vec3(0.24, 0.24, 0.40);
	ALBEDO = mix(mix(day, vec3(0.72, 0.72, 0.76), rain), dusk, night);
	ALBEDO *= mix(1.0, 0.8 * mix(0.78, 1.0, smoothstep(0.3, 0.75, body * 0.6 + wisps * 0.5)), billow);
	if (debug_view == 4) { ALBEDO = vec3(1.0, 1.0, 0.0); ALPHA = a > 0.02 ? 1.0 : 0.0; }
}
