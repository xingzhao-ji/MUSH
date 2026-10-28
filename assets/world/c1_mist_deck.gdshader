shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Concept-1 valley mist deck (prototype, visual only): a near-horizontal layer of soft billowing mist over the
// basin floor, seen from the cliff-top terrace as in design-reference/mush-concept-1.png (the islands rise out
// of white-violet cloud; only glimpses of the river show). Broken by slow drifting noise into banks with gaps,
// feathered at the quad's edges, softened where it meets terrain or rock (depth buffer), faded close to the
// camera, and faded out when the camera is near or below the deck (it never reads as a ceiling from the shore).
// Unshaded; lilac in shade, pink-peach toward the glow; dusky violet at night, grey in rain.
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float strength = 0.7;
uniform float deck_y = -70.0;
uniform float coverage = 0.5;
uniform vec3 day_tint : source_color = vec3(0.80, 0.79, 0.92);
uniform vec3 glow_tint : source_color = vec3(0.95, 0.82, 0.84);
uniform vec3 glow_dir = vec3(0.0, 0.0, -1.0);
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
	float drift = shimmer_time * 0.004 * shimmer_amount;
	vec2 q = v_world.xz * 0.0045 + vec2(drift, -drift * 0.6);
	float banks = fbm(q + vec2(deck_y * 0.013));
	float detail = fbm(q * 3.7 - vec2(drift * 2.0, 1.3));
	float body = smoothstep(1.0 - coverage - 0.18, 1.0 - coverage + 0.22, banks * 0.8 + detail * 0.35);
	float edges = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x) * smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	float a = body * edges;
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -upos.z / upos.w;
	float frag_z = -VERTEX.z;
	a *= clamp((scene_z - frag_z) / 25.0, 0.0, 1.0);
	a *= smoothstep(60.0, 180.0, frag_z);
	a *= smoothstep(deck_y + 15.0, deck_y + 70.0, CAMERA_POSITION_WORLD.y);
	ALPHA = clamp(a * strength * mix(1.0, 1.2, rain) * mix(1.0, 0.75, night), 0.0, 1.0);
	vec3 to_frag = normalize(v_world - CAMERA_POSITION_WORLD);
	float toward = smoothstep(-0.1, 0.95, dot(normalize(to_frag.xz + vec2(1e-5)), normalize(glow_dir.xz + vec2(1e-5))));
	// billows: brighter crowns, lilac hollows
	float lit = smoothstep(0.35, 0.8, detail * 0.7 + banks * 0.4);
	vec3 day = mix(day_tint * 0.86, mix(day_tint, glow_tint, toward), lit);
	ALBEDO = mix(mix(day, vec3(0.72, 0.72, 0.76), rain), vec3(0.22, 0.22, 0.38), night);
}
