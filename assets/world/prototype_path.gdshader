shader_type spatial;
render_mode cull_back;
// Prototype walking-ribbon surface (existing route and slice share it). Visual only: ribbon
// geometry, collision and the walkable corridor are unchanged. A narrow, meandering
// worn-earth track runs on the tread and fades through trampled grass into moss shoulders
// and embankment skirts that use the far terrain's own moss tone, so the ribbon edge melts
// into the ground. Lateral position comes from the ribbon UV (u 0..1 across tread and both
// shoulders; skirts sit at u 0 or 1); all patterns use world XZ, so the two ribbons
// continue through their junction without a visible restart.
uniform sampler2D moss_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 moss_mean : source_color = vec3(0.30, 0.36, 0.18);
uniform float moss_scale = 0.28;
uniform vec4 clearing_rect = vec4(0.0);
uniform vec3 clearing_gain = vec3(1.0);
uniform float total_width = 8.0;
uniform float track_half = 0.95;
// Rock01 reads reddish under this light, so a near-neutral tint gives packed earth at about
// the old ribbon's brightness but far less orange (old tint 0.86, 0.66, 0.48).
uniform vec3 earth_tint : source_color = vec3(0.78, 0.80, 0.70);
uniform float earth_scale = 0.22;
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
// Shading only: the shoulders and skirts fall away from the tread (18 degrees), which put a
// lighting crease at the tread edge. Leaning their shading normal toward up lets the moss
// verge light like the neighbouring ground; the geometry and collision stay as built.
void fragment() {
	vec2 xz = v_world.xz;
	float dist = length(VERTEX);
	float lateral = (UV.x - 0.5) * total_width;
	// Moss: the gentle-ground branch of far_terrain.gdshader (clearing feather, near detail
	// fading to the measured mean, macro tone, damp valley floor, final macro brightness).
	float macro = fbm(xz * 0.004);
	vec2 outside = max(max(clearing_rect.xy - xz, xz - clearing_rect.zw), vec2(0.0));
	float feather = 1.0 - smoothstep(0.0, 45.0, length(outside) + (fbm(xz * 0.03) - 0.5) * 40.0);
	vec3 far_moss = moss_mean * mix(vec3(1.0), clearing_gain, feather);
	vec3 moss = far_moss;
	if (dist < 80.0) {
		vec2 uv = xz * moss_scale;
		vec3 detail = mix(texture(moss_tex, uv).rgb, texture(moss_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.41 + 0.37).rgb, 0.4);
		moss = mix(detail, far_moss, smoothstep(20.0, 80.0, dist));
	}
	moss *= mix(vec3(0.92, 1.02, 0.95), vec3(1.08, 1.0, 0.86), macro);
	moss = mix(moss, moss * vec3(0.62, 0.86, 0.84), smoothstep(-25.0, -60.0, v_world.y));
	moss *= 0.88 + 0.24 * macro;
	// Worn track: meanders inside the tread, varies in width, ragged edge, plus scattered
	// bare patches on the rest of the tread. Shoulders and skirts stay grass.
	float wander = (fbm(xz * 0.045 + 7.1) - 0.5) * 0.9;
	float half_w = track_half * (0.8 + 0.45 * fbm(xz * 0.25 + 2.3));
	float d = abs(lateral - wander) + (fbm(xz * 1.6 + 4.7) - 0.5) * 0.5;
	float bare = 1.0 - smoothstep(half_w - 0.15, half_w + 0.35, d);
	float patches = smoothstep(0.66, 0.76, fbm(xz * 0.5 + 9.7)) * (1.0 - smoothstep(1.0, 1.6, abs(lateral)));
	bare = max(bare, patches * 0.8);
	// Trampled grass between the track and the verge: drier and flatter than the moss.
	float trampled = 1.0 - smoothstep(half_w + 0.2, half_w + 1.4, d);
	vec3 grass = mix(moss, moss * vec3(1.06, 1.02, 0.86), trampled * 0.4);
	// Packed earth: Rock01 at two scales, desaturated warm tint, damp/dry mottling.
	float grit = dot(texture(rock_tex, xz * earth_scale * 3.7 + 0.29).rgb, vec3(0.333));
	vec3 earth = texture(rock_tex, xz * earth_scale).rgb * (0.7 + 0.75 * grit);
	earth *= earth_tint * (0.86 + 0.28 * fbm(xz * 0.9));
	ALBEDO = mix(grass, earth, bare);
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, smoothstep(1.4, 2.6, abs(lateral)) * 0.8));
	ROUGHNESS = mix(0.95, 0.9, bare);
	SPECULAR = mix(0.12, 0.2, bare);
}
