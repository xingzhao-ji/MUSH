shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
// Prototype lake surface (replaces far_water.gdshader on the lake only).
// - Colour from the vertical water depth to the opaque lake bed (depth buffer): warm shallows,
//   teal, then deep blue-green, independent of the viewing angle.
// - Schlick fresnel (F0 0.02). The reflection is a short screen-space march along the
//   ripple-perturbed reflected ray over the opaque scene (far bank, cliffs, giants); rays that
//   reach open sky sample the on-screen sky, else the sky gradient set by apply_look.
// - SPECULAR 0: the engine's own sky reflection and highlight are off (they would double the
//   reflection); a broad, weak sun glint is added here and fades out at night and in rain.
// - The shore contact fades over the first ~0.45 m of depth (opacity and reflection).
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shore_tint : source_color = vec3(0.20, 0.19, 0.13);
uniform vec3 shallow : source_color = vec3(0.22, 0.42, 0.40);
uniform vec3 deep : source_color = vec3(0.03, 0.11, 0.16);
uniform vec3 sky_top : source_color = vec3(0.24, 0.45, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.94, 0.86, 0.74);
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform bool debug_unlit = false;
// Capture-only switch (set_debug_mask): false keeps the sky-gradient reflection only.
uniform bool screen_reflection = true;
// Diagnostic only: tint pixels whose accepted reflection sample needed the sideways clamp.
uniform bool debug_side_clamp = false;
uniform vec3 sun_dir = vec3(0.77, 0.4, -0.64);
// Stream inflow (0 strength = off): where the outlet stream meets the lake, a paler, silty fan
// with foam streaks spreads along the inflow direction. inflow = (x, z, dir x, dir z) at the
// waterline; inflow_size = (reach m, strength).
uniform vec4 inflow = vec4(0.0);
uniform vec2 inflow_size = vec2(0.0);
// Painterly reflectance floor (0 = physical Schlick only): seen from the high vista (~70 deg from
// grazing) Schlick gives ~0.12 and the lake read as a dark hole (L*11 vs the concept's 38,
// review 06); the floor lets it mirror the glowing sky and walls as the concepts do.
uniform float reflect_floor = 0.0;
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
// View-space position of the opaque scene at a screen uv.
vec3 scene_view(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}
bool on_screen(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}
// Rays that leave the screen sideways keep marching against the nearest screen column (the
// adjacent bank stands in); only leaving through the top or bottom ends the march.
vec2 clamp_side(vec2 uv) {
	return vec2(clamp(uv.x, 0.002, 0.998), uv.y);
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 bed_view = scene_view(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bed = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float depth_v = max(0.0, v_world.y - bed.y);
	float thickness = max(0.0, length(bed_view) - length(VERTEX));
	// Ripple normal from finite differences of the ripple field.
	vec2 p = v_world.xz;
	float e = 0.6;
	float c = ripples(p);
	vec3 slope = vec3(ripples(p + vec2(e, 0.0)) - c, 0.0, ripples(p + vec2(0.0, e)) - c) * mix(0.35, 0.6, rain);
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	vec3 view_dir = normalize(v_world - cam);
	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(-view_dir, n_world), 0.0, 1.0), 5.0);
	fresnel = max(fresnel, reflect_floor);
	// Body colour by vertical depth.
	vec3 body = mix(shore_tint, shallow, smoothstep(0.0, 2.5, depth_v));
	body = mix(body, deep, smoothstep(2.5, 14.0, depth_v));
	float plume = 0.0;
	float plume_foam = 0.0;
	if (inflow_size.y > 0.0) {
		vec2 fwd = normalize(inflow.zw);
		vec2 d = v_world.xz - inflow.xy;
		float along = dot(d, fwd);
		float side = dot(d, vec2(-fwd.y, fwd.x));
		float spread = 5.0 + max(along, 0.0) * 0.5;
		float wob = vnoise(v_world.xz * 0.07 + vec2(shimmer_time * shimmer_amount * 0.02)) - 0.5;
		plume = exp(-pow(side / spread + wob * 0.9, 2.0)) * smoothstep(-8.0, 2.0, along) * (1.0 - smoothstep(inflow_size.x * 0.35, inflow_size.x, along)) * inflow_size.y;
		float streak = vnoise(vec2(side * 0.4, along * 0.07 - shimmer_time * shimmer_amount * 0.15));
		plume_foam = smoothstep(0.42, 0.68, streak) * plume * (1.0 - smoothstep(0.0, inflow_size.x * 0.5, along));
		// White water meeting still water: a broken foam patch right at the entry.
		plume_foam = max(plume_foam, smoothstep(22.0, 0.0, abs(along)) * smoothstep(0.28, 0.52, vnoise(v_world.xz * 0.5 + vec2(shimmer_time * shimmer_amount * 0.1))) * plume);
		body = mix(body, vec3(0.30, 0.40, 0.36), plume * 0.6);
	}
	body = mix(body, body * vec3(0.55, 0.62, 0.85), night);
	// Reflection: geometric march (3 m, x1.6 per step) with bisection on the first crossing.
	vec3 n_refl = normalize(mix(vec3(0.0, 1.0, 0.0), n_world, 0.45 + 0.35 * rain));
	vec3 r = reflect(view_dir, n_refl);
	r.y = max(r.y, 0.002);
	r = normalize(r);
	vec3 reflection = mix(sky_horizon, sky_top, pow(clamp(r.y, 0.0, 1.0), 0.45));
	float t_prev = 0.0;
	float t = 3.0;
	float hit = 0.0;
	vec2 hit_uv = vec2(0.0);
	bool side_clamped = false;
	for (int i = 0; i < (screen_reflection ? 14 : 0); i++) {
		vec4 qv = VIEW_MATRIX * vec4(v_world + r * t, 1.0);
		vec4 clip = PROJECTION_MATRIX * qv;
		if (clip.w <= 0.0) break;
		vec2 uv = clamp_side(clip.xy / clip.w * 0.5 + 0.5);
		if (!on_screen(uv)) break;
		vec3 s = scene_view(uv, INV_PROJECTION_MATRIX);
		if (qv.z < s.z) {
			// Behind the scene surface: refine, then accept unless it passed behind a thin occluder.
			float lo = t_prev;
			float hi = t;
			for (int k = 0; k < 4; k++) {
				float mid = 0.5 * (lo + hi);
				vec4 mv = VIEW_MATRIX * vec4(v_world + r * mid, 1.0);
				vec4 mc = PROJECTION_MATRIX * mv;
				vec2 muv = clamp_side(mc.xy / mc.w * 0.5 + 0.5);
				if (mv.z < scene_view(muv, INV_PROJECTION_MATRIX).z) hi = mid; else lo = mid;
			}
			vec4 fv = VIEW_MATRIX * vec4(v_world + r * hi, 1.0);
			vec4 fc = PROJECTION_MATRIX * fv;
			float raw_x = fc.x / fc.w * 0.5 + 0.5;
			side_clamped = raw_x < 0.002 || raw_x > 0.998;
			vec2 fuv = clamp_side(fc.xy / fc.w * 0.5 + 0.5);
			if (on_screen(fuv) && scene_view(fuv, INV_PROJECTION_MATRIX).z - fv.z < (t - t_prev) * 0.25 + 1.5) {
				hit_uv = fuv;
				hit = 1.0;
			}
			break;
		}
		t_prev = t;
		t *= 1.6;
	}
	if (hit > 0.0) {
		hit *= smoothstep(0.0, 0.06, min(hit_uv.y, 1.0 - hit_uv.y));
		reflection = mix(reflection, textureLod(screen_tex, hit_uv, rain * 2.0).rgb, hit);
	} else if (screen_reflection) {
		// Open sky: the on-screen sky in the reflected direction, when it is visible.
		vec4 sc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cam + r * 2000.0, 1.0));
		if (sc.w > 0.0) {
			vec2 suv = clamp_side(sc.xy / sc.w * 0.5 + 0.5);
			if (on_screen(suv) && -scene_view(suv, INV_PROJECTION_MATRIX).z > 2000.0) {
				reflection = mix(reflection, textureLod(screen_tex, suv, 1.0).rgb, smoothstep(0.0, 0.06, min(suv.y, 1.0 - suv.y)));
			}
		}
	}
	// Broad, weak sun glint on a smoothed normal (no per-ripple sparkle).
	vec3 n_glint = normalize(mix(vec3(0.0, 1.0, 0.0), n_world, 0.5));
	float glint = pow(max(dot(n_glint, normalize(normalize(sun_dir) - view_dir)), 0.0), 220.0) * (1.0 - night) * (1.0 - 0.7 * rain);
	// Composite: transmitted body (lit albedo) plus reflection (emission), softened at the shore.
	float soft = smoothstep(0.0, 0.45, depth_v);
	float body_alpha = max(1.0 - exp(-thickness * 0.3), plume * 0.55) * soft;
	float f = fresnel * soft;
	float alpha = clamp(max(body_alpha + f * (1.0 - body_alpha), plume_foam * 0.9 * max(soft, 0.6)), 0.0, 1.0);
	if (debug_side_clamp && hit > 0.0 && side_clamped) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(1.0, 0.0, 1.0);
	} else if (debug_unlit) {
		EMISSION = body;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = mix(body * (1.0 - f), vec3(0.82, 0.86, 0.86), plume_foam);
		EMISSION = (reflection * f + vec3(1.0, 0.86, 0.66) * glint * 0.6 * soft) / max(alpha, 0.05);
		// Night: a faint moonlit-sky sheen on the open water (seen from above, the deep lake read as a
		// black hole, L*2 against a sky of 12; review 03). Shallows and the shore contact stay as they were.
		EMISSION += vec3(0.012, 0.018, 0.042) * night * smoothstep(1.0, 4.0, depth_v) * (1.0 - f);
	}
	ALPHA = alpha;
	ROUGHNESS = 0.3;
	SPECULAR = 0.0;
}
