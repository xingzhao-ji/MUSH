shader_type spatial;
render_mode cull_back;
// Coarse far terrain: existing moss albedo on gentle ground and existing Rock01 on steep
// ground, both world-space at real scale. The moss texture is imported without mipmaps
// (import settings kept), so its detail fades to its measured mean colour with distance
// instead of aliasing. debug_unlit shows the terrain's own colour with no lighting.
uniform sampler2D moss_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 moss_mean : source_color = vec3(0.30, 0.36, 0.18);
uniform float moss_scale = 0.28;
uniform float rock_scale = 0.12;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform bool debug_unlit = false;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
uniform vec3 warm_rock : source_color = vec3(0.66, 0.55, 0.44);
uniform vec3 cool_rock : source_color = vec3(0.46, 0.45, 0.50);
varying vec3 v_world;
varying vec3 v_normal;

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
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = normalize(v_normal);
	float dist = length(VERTEX);
	float h = v_world.y;
	float macro = fbm(v_world.xz * 0.004);
	// Moss: two rotated scales break tiling; detail fades to the mean with distance.
	// Fetch the moss texture only where its detail is visible: it has no mipmaps, and
	// minified fetches across the whole far terrain thrash the texture cache.
	vec3 moss = moss_mean;
	if (dist < 80.0) {
		vec2 uv = v_world.xz * moss_scale;
		vec3 detail = mix(texture(moss_tex, uv).rgb, texture(moss_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.41 + 0.37).rgb, 0.4);
		moss = mix(detail, moss_mean, smoothstep(20.0, 80.0, dist));
	}
	moss *= mix(vec3(0.92, 1.02, 0.95), vec3(1.08, 1.0, 0.86), macro);
	// Damp valley floor, then a narrow sandy shore band at the lake level.
	moss = mix(moss, moss * vec3(0.62, 0.86, 0.84), smoothstep(-25.0, -60.0, h));
	vec3 sand = vec3(0.40, 0.36, 0.30) * (0.85 + 0.3 * fbm(v_world.xz * 0.4));
	moss = mix(moss, sand, smoothstep(-79.6, -81.4, h) * smoothstep(-83.2, -81.6, h) * 0.85);
	// Rock: triplanar Rock01 with erosion streaks that run down the slope, not bands.
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 rock = texture(rock_tex, v_world.zy * rock_scale).rgb * w.x + texture(rock_tex, v_world.xz * rock_scale).rgb * w.y + texture(rock_tex, v_world.xy * rock_scale).rgb * w.z;
	float streak = fbm(vec2((v_world.x + v_world.z) * 0.06, h * 0.008 + fbm(v_world.xz * 0.02) * 0.6));
	rock *= mix(cool_rock, warm_rock, streak) * 1.35;
	float steep = 1.0 - clamp(n.y, 0.0, 1.0);
	float rockiness = smoothstep(0.26, 0.46, steep + (macro - 0.5) * 0.18);
	// Moss creeps onto the tops of rock ledges.
	rockiness *= 1.0 - smoothstep(0.55, 0.85, n.y) * 0.6;
	vec3 albedo = mix(moss, rock, rockiness);
	albedo *= 0.88 + 0.24 * macro;
	if (debug_unlit) {
		EMISSION = albedo;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = albedo;
	}
	ROUGHNESS = mix(0.95, 0.82, rockiness);
	SPECULAR = 0.12;
}
