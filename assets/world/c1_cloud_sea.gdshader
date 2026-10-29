shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;
// C1-only cloud banks: bounded ray integration through world-space ellipsoids.
// A native BoxMesh bounds each bank; its back faces are only a ray container.
// Both ends of every ray are analytic ellipsoid intersections, and the opaque
// scene depth caps the far end. No screen-facing cards or rectangular edges.
// Static 3D noise: no autonomous TIME, new wind source, or physics interaction.
uniform vec3 bank_center = vec3(0.0);
uniform vec3 bank_radii = vec3(300.0, 65.0, 240.0);
uniform float density : hint_range(0.0, 0.05) = 0.017;
uniform float seed = 0.0;
uniform float lobe_strength : hint_range(0.0, 1.0) = 0.55;
uniform int march_steps : hint_range(6, 16) = 12;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform vec3 sun_dir = vec3(-0.4, 0.7, 0.3);
uniform vec3 cloud_lit : source_color = vec3(0.94, 0.85, 0.83);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.54, 0.72);
uniform vec3 cloud_warm : source_color = vec3(0.80, 0.76, 0.79);
uniform vec3 cloud_night_lit : source_color = vec3(0.38, 0.40, 0.57);
uniform vec3 cloud_night_shade : source_color = vec3(0.15, 0.16, 0.28);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 world_surface;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
		mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
		mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float cloud_noise(vec3 p) {
	return noise3(p) * 0.72 + noise3(p * 2.13 + vec3(4.9, 1.7, 8.1)) * 0.28;
}
vec4 lobe_field(vec3 p, vec3 center, vec3 radii) {
	vec3 delta = p - center;
	return vec4(delta / (radii * radii), length(delta / radii));
}
vec4 join_lobes(vec4 a, vec4 b) {
	float blend = clamp(0.5 + 0.5 * (b.w - a.w) / 0.20, 0.0, 1.0);
	return vec4(mix(b.xyz, a.xyz, blend), mix(b.w, a.w, blend) - 0.20 * blend * (1.0 - blend));
}
vec4 cloud_shape(vec3 p) {
	// Four overlapping rounded bodies, all contained by the outer ellipsoid.
	// The dominant body's gradient also gives a stable broad lighting direction.
	vec4 field = lobe_field(p, vec3(-0.37, -0.02, 0.09), vec3(0.64, 0.73, 0.73));
	vec4 other = lobe_field(p, vec3(0.14, 0.18, -0.19), vec3(0.65, 0.81, 0.67));
	field = join_lobes(field, other);
	other = lobe_field(p, vec3(0.43, -0.10, 0.26), vec3(0.57, 0.65, 0.66));
	field = join_lobes(field, other);
	other = lobe_field(p, vec3(-0.08, -0.21, -0.38), vec3(0.69, 0.53, 0.60));
	field = join_lobes(field, other);
	return field;
}
void vertex() {
	world_surface = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 ray = normalize(world_surface - CAMERA_POSITION_WORLD);
	vec3 origin = (CAMERA_POSITION_WORLD - bank_center) / bank_radii;
	vec3 direction = ray / bank_radii;
	float a = dot(direction, direction);
	float b = dot(origin, direction);
	float c = dot(origin, origin) - 1.0;
	float discriminant = b * b - a * c;
	float opacity = 0.0;
	vec3 integrated = vec3(0.0);
	if (discriminant > 0.0 && a > 0.000000001) {
		float root = sqrt(discriminant);
		float near_t = max((-b - root) / a, 0.0);
		float far_t = (-b + root) / a;
		float scene_depth = texture(depth_tex, SCREEN_UV).r;
		vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
		// Forward+ reverse-Z reconstruction has positive homogeneous w. The
		// epsilon also keeps a cleared far-depth pixel finite on an infinite far plane.
		scene_view.xyz /= max(scene_view.w, 0.000001);
		float opaque_t = length(scene_view.xyz);
		far_t = min(far_t, opaque_t);
		if (far_t > near_t) {
			float step_length = (far_t - near_t) / float(march_steps);
			vec3 light_direction = normalize(sun_dir + vec3(0.0001));
			for (int i = 0; i < 16; i++) {
				if (i >= march_steps) { break; }
				float t = near_t + (float(i) + 0.5) * step_length;
				vec3 p = CAMERA_POSITION_WORLD + ray * t;
				vec3 local = (p - bank_center) / bank_radii;
				vec3 q = p * vec3(0.012, 0.018, 0.012) + vec3(seed, seed * 0.37, seed * 0.71);
				float billows = cloud_noise(q);
				float radius = length(local);
				vec4 shape = cloud_shape(local);
				float contour = mix(radius, shape.w, lobe_strength) + (0.5 - billows) * 0.10;
				float envelope = 1.0 - smoothstep(0.86, 1.0, radius);
				float boundary = envelope * (1.0 - smoothstep(0.51, 0.99, contour));
				float body = smoothstep(0.22, 0.72, billows + boundary * 0.18);
				float extinction = density * boundary * body;
				float sample_alpha = 1.0 - exp(-extinction * step_length);
				vec3 gradient = mix(local, shape.xyz, lobe_strength) / bank_radii;
				vec3 normal = normalize(gradient + vec3(0.000001));
				vec3 top_light = normalize(vec3(light_direction.x, max(light_direction.y, 0.55), light_direction.z));
				float sunlit = max(dot(normal, top_light), 0.0);
				float crown = clamp(0.12 + sunlit * 0.76 + local.y * 0.12 + (billows - 0.5) * 0.16, 0.0, 1.0);
				vec3 day_color = mix(cloud_shade, cloud_lit, smoothstep(0.1, 0.9, crown));
				day_color = mix(day_color, cloud_warm, smoothstep(0.62, 0.95, crown) * 0.23);
				day_color = mix(day_color, mix(vec3(0.27, 0.29, 0.37), vec3(0.51, 0.51, 0.56), crown), rain * 0.60);
				vec3 color = mix(day_color, mix(cloud_night_shade, cloud_night_lit, crown), night);
				integrated += (1.0 - opacity) * sample_alpha * color;
				opacity += (1.0 - opacity) * sample_alpha;
				if (opacity > 0.985) { break; }
			}
		}
	}
	ALBEDO = integrated / max(opacity, 0.0001);
	// Restrained height/distance fades reduce the cloud effect for low or nearby
	// cameras. These controls do not establish visibility at every gameplay pose.
	float high_view = smoothstep(bank_center.y - bank_radii.y * 0.6, bank_center.y + bank_radii.y * 0.15, CAMERA_POSITION_WORLD.y);
	float close_fade = smoothstep(100.0, 210.0, distance(CAMERA_POSITION_WORLD, bank_center));
	ALPHA = min(opacity * high_view * close_fade, 0.985);
	// The volume already supplies its own aerial colour. Engine endpoint fog would
	// otherwise flatten the cloud sea to the same solid colour as the far wall.
	FOG = vec4(vec3(0.0), 0.0);
}
