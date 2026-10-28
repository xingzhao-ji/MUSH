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
// Clearing edge feather: baked ground extent (x0, z0, x1, z1) and the far-moss tone gain
// that matches the clearing's average colour, applied with an irregular boundary.
uniform vec4 clearing_rect = vec4(0.0);
uniform vec3 clearing_gain = vec3(1.0);
// Rock readability inside one region only (the cliff detail patch: x0, z0, x1, z1), fading out
// over an irregular ~250 m band inside its edges (no visible rectangle) and weighted by
// rockiness; outside the region and at zero strengths it renders exactly as before.
// breakup: neutral mineral tone, isotropic multi-scale mottling, broken strata and ledge
// lichen; relief: procedural normal
// variation; fill: sky-bounce fill on faces turned from the sun (still fogged, dimmed at night).
uniform vec4 rock_focus_rect = vec4(0.0);
uniform float rock_breakup = 0.0;
uniform float rock_relief = 0.0;
uniform float rock_fill = 0.0;
// At 300-600 m the far texture pair multiplies two dark layers and collapses rock albedo to
// ~0.03-0.05 (darker than coal); albedo_lift restores a natural rock range inside the region.
uniform float rock_albedo_lift = 1.0;
uniform vec3 rock_fill_tint : source_color = vec3(0.62, 0.60, 0.72);
// Golden-hour soft daylight (all zero = previous look): wrap lighting on the key (key_light = sun
// colour x energy, linear) added as emission so the stock light path and specular stay as they
// are, plus a lavender-sky / warm-bounce hemisphere term; faded out by soft_range so the far walls
// keep their tone under the haze. With shadows off, the low back-side key alone left the near
// zone black (vista bottom-left quarter 64% below L*28, consult 01 step 4).
uniform vec3 key_light = vec3(0.0);
uniform float wrap_light = 0.0;
uniform vec3 hemi_sky = vec3(0.0);
uniform vec3 hemi_ground = vec3(0.0);
uniform float soft_range = 900.0;
// Tended ground (x, z, radius m, strength; strength 0 = off): moss instead of exposed rock inside the
// disc, e.g. the vista refuge's terrace (review 10: it read as grey gravel).
uniform vec4 garden_disc = vec4(0.0);
// Skylight on the tended ground (0 = off): the hero's far bank faces away from the low back sun.
uniform float garden_fill = 0.0;
// Skylight on escarpment shelf tops (0 = off).
uniform float ledge_fill = 0.0;
// Shelf-top grass: gain on the (partly desaturated) moss mean, how much it is desaturated, fleck
// variation, and how far the rock risers are dimmed. Defaults keep the previous look.
uniform vec3 ledge_grass = vec3(2.7, 2.75, 2.15);
uniform float ledge_desat = 0.55;
uniform float ledge_fleck = 0.2;
uniform float ledge_riser_dim = 0.62;
uniform vec3 ledge_riser_tint = vec3(1.0);
// Grass over the steep face between the shelves (x, z, radius m, strength; 0 = off): the goal's hillside
// below the cottage is grass with rock steps, not rock with grass trims.
uniform vec4 face_grass_disc = vec4(0.0);
// Lake shore: height of the dark wet band above the water (m) and the strength of the grey gravel strip.
uniform vec2 shore_wet = vec2(0.5, 0.9);
// Skylight on the back-lit near slopes in front of a review camera (x, z, radius m, strength; 0 = off).
uniform vec4 near_fill_disc = vec4(0.0);
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
vec3 soft_daylight(vec3 n, vec3 albedo, float dist) {
	float ndl = dot(n, normalize(sun_dir));
	float wrap_extra = max(0.0, (ndl + wrap_light) / (1.0 + wrap_light)) - max(0.0, ndl);
	vec3 hemi = mix(hemi_ground, hemi_sky, clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
	return albedo * (key_light * wrap_extra + hemi) * (1.0 - smoothstep(soft_range * 0.6, soft_range, dist));
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
	vec2 outside = max(max(clearing_rect.xy - v_world.xz, v_world.xz - clearing_rect.zw), vec2(0.0));
	float feather = 1.0 - smoothstep(0.0, 45.0, length(outside) + (fbm(v_world.xz * 0.03) - 0.5) * 40.0);
	vec3 far_moss = moss_mean * mix(vec3(1.0), clearing_gain, feather);
	vec3 moss = far_moss;
	if (dist < 80.0) {
		vec2 uv = v_world.xz * moss_scale;
		vec3 detail = mix(texture(moss_tex, uv).rgb, texture(moss_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.41 + 0.37).rgb, 0.4);
		moss = mix(detail, far_moss, smoothstep(20.0, 80.0, dist));
	}
	moss *= mix(vec3(0.92, 1.02, 0.95), vec3(1.08, 1.0, 0.86), macro);
	// Meadow structure (the open slopes read as one flat saturated lawn): large soft patches of
	// darker clover hollows and warm dry grass, and a little less saturation. (Shader-painted
	// flower dots were tried and read as scattered litter, sweep 180054; meadow flowers need geometry.)
	float meadow_patch = fbm(v_world.xz * 0.018 + vec2(fbm(v_world.xz * 0.005) * 3.0));
	// Warmer, lighter, less saturated than the raw moss (review 03: near grass L*22-30, hue 69,
	// saturation 0.87; target hue 50-60, saturation <= 0.6, L*32-40).
	// Faded out over the clearing feather, where the far moss is matched to the baked clearing.
	vec3 meadow = moss * mix(vec3(0.96, 0.96, 0.82), vec3(1.20, 1.07, 0.78), smoothstep(0.3, 0.75, meadow_patch));
	meadow = mix(meadow, vec3(dot(meadow, vec3(0.299, 0.587, 0.114))), 0.45) * 1.42;
	moss = mix(meadow, moss, feather);
	// Damp valley floor.
	moss = mix(moss, moss * vec3(0.62, 0.86, 0.84), smoothstep(-25.0, -60.0, h));
	// Lake shore (lake level -82 m). A uniform pale sand ring read as a kiddie-pool rim and as a
	// glowing outline at night; instead: a broken grey gravel strip up to ~1.4 m above the water,
	// a dark wet margin at the waterline (sharper, glossier) and a dark sediment bed below it, so
	// the shallows read as clear water over a dark bed.
	float shore_n = fbm(v_world.xz * 0.09 + vec2(fbm(v_world.xz * 0.02) * 2.0));
	float lake_h = h + 82.0 + (shore_n - 0.5) * 0.5;
	float pebble = fbm(v_world.xz * 0.7 + 3.3);
	float gravel_m = smoothstep(1.4, 0.7, lake_h) * smoothstep(-0.1, 0.25, lake_h) * smoothstep(0.38, 0.55, shore_n);
	vec3 gravel_c = mix(vec3(0.14, 0.14, 0.13), vec3(0.23, 0.22, 0.21), smoothstep(0.35, 0.7, pebble));
	moss = mix(moss, gravel_c, gravel_m * shore_wet.y);
	float wet = smoothstep(shore_wet.x, 0.0, lake_h);
	moss *= mix(1.0, 0.5, wet);
	vec3 bed = mix(vec3(0.15, 0.14, 0.10), vec3(0.08, 0.09, 0.07), smoothstep(-0.2, -1.6, lake_h));
	moss = mix(moss, bed, smoothstep(0.0, -0.4, lake_h));
	float wet_margin = smoothstep(0.3, 0.0, lake_h) * smoothstep(-0.6, -0.1, lake_h);
	// Rock: triplanar Rock01 with erosion streaks that run down the slope, not bands.
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// Texture scale by distance: near pair (8 m + 33 m tiles), far pair (33 m + 130 m),
	// blended over 150-600 m so neither tiles visibly nor turns to noise.
	float far_t = smoothstep(150.0, 600.0, dist);
	float big = rock_scale * 0.25;
	vec3 broad = texture(rock_tex, v_world.zy * big + 0.31).rgb * w.x + texture(rock_tex, v_world.xz * big + 0.57).rgb * w.y + texture(rock_tex, v_world.xy * big + 0.13).rgb * w.z;
	vec3 rock = broad;
	if (far_t < 1.0) {
		vec3 fine = texture(rock_tex, v_world.zy * rock_scale).rgb * w.x + texture(rock_tex, v_world.xz * rock_scale).rgb * w.y + texture(rock_tex, v_world.xy * rock_scale).rgb * w.z;
		rock = mix(fine * broad * 2.0, rock, far_t);
	}
	if (far_t > 0.0) {
		float huge = rock_scale * 0.0625;
		vec3 vast = texture(rock_tex, v_world.zy * huge + 0.71).rgb * w.x + texture(rock_tex, v_world.xz * huge + 0.19).rgb * w.y + texture(rock_tex, v_world.xy * huge + 0.43).rgb * w.z;
		rock = mix(rock, broad * vast * 2.0, far_t);
	}
	float streak = fbm(vec2((v_world.x + v_world.z) * 0.06, h * 0.008 + fbm(v_world.xz * 0.02) * 0.6));
	rock *= mix(cool_rock, warm_rock, streak) * 1.35;
	// Geological strata: warped, uneven-thickness layers of tone (not a periodic band).
	float strata = fbm(vec2(h * 0.045 + fbm(v_world.xz * 0.006) * 1.6, 0.37));
	rock *= mix(0.80, 1.12, strata);
	float focus = 0.0;
	if (rock_focus_rect.z > rock_focus_rect.x) {
		vec2 inside = min(v_world.xz - rock_focus_rect.xy, rock_focus_rect.zw - v_world.xz);
		float edge = min(inside.x, inside.y);
		focus = edge > 0.0 ? smoothstep(0.0, 250.0, edge + (fbm(v_world.xz * 0.004) - 0.5) * 120.0) : 0.0;
	}
	if (focus > 0.0 && rock_breakup > 0.0) {
		// Restrained mineral colour: pull the warm far-texture product halfway to neutral stone.
		float lum = dot(rock, vec3(0.299, 0.587, 0.114));
		vec3 stone = mix(rock, vec3(lum) * vec3(1.04, 1.0, 0.96), 0.5);
		// Irregular multi-scale mottling, equal scale across and up the face so it never streaks.
		float m_big = fbm(vec2((v_world.x - v_world.z) * 0.018, h * 0.018));
		float m_mid = fbm(vec2((v_world.x + v_world.z) * 0.07, h * 0.07) + 7.3);
		vec3 mottle = mix(vec3(0.80, 0.81, 0.84), vec3(1.16, 1.11, 1.04), m_big) * mix(0.86, 1.12, m_mid);
		// Discontinuous strata: thin, uneven, slightly tilted bands that break off along the face.
		float level = h + 9.0 * fbm(v_world.xz * 0.008);
		float band = smoothstep(0.75, 0.95, sin(level * 0.42) * 0.5 + 0.5);
		float breaks = smoothstep(0.45, 0.62, fbm(v_world.xz * 0.025 + vec2(h * 0.01)));
		vec3 strata_tone = mix(vec3(1.0), vec3(0.80, 0.79, 0.78), band * breaks);
		rock = mix(rock, stone * mottle * strata_tone, rock_breakup * focus);
	}
	if (focus > 0.0) rock *= mix(1.0, rock_albedo_lift, focus);
	// Outside the focus region, steep terrain rock joins the granite family: the warm far-texture
	// product (Rock01 x warm_rock) read as maroon value holes beside the grey walls; 0.55 still left
	// the lifted banks red-clay (sweep 184318), so 0.8.
	float g_lum = dot(rock, vec3(0.299, 0.587, 0.114));
	rock = mix(rock, vec3(g_lum) * vec3(1.02, 1.0, 0.98) * 1.25, 0.8 * (1.0 - focus));
	// The same two-texture product also collapses rock albedo outside the focus region (measured
	// sRGB ~(44, 27, 16) on the vista's sunlit-side bank at ~300 m: coal, read as red mud); lift
	// it toward the focus region's level, more with distance where the far pair takes over.
	// 1.6 -> 2.3 near (review 04: the vista's near plateau cliff and the midground mound, both rock
	// outside the focus region at 150-400 m, read L*28-31 against 40-55 wanted).
	rock *= mix(1.0, mix(2.3, 2.5, far_t), 1.0 - focus);
	float steep = 1.0 - clamp(n.y, 0.0, 1.0);
	// Moss coverage: mottled, warped world-space patches (~22 m and ~6 m), thinning on
	// steep and high, exposed ground. Applied only on rugged or upland terrain, so the
	// meadows stay mossy; nothing follows mesh triangles.
	float mottle = fbm(v_world.xz * 0.045 + vec2(fbm(v_world.xz * 0.012), fbm(v_world.xz * 0.012 + 5.2)) * 1.5);
	float fleck = fbm(v_world.xz * 0.16 + 3.1);
	float exposure = smoothstep(0.18, 0.55, steep);
	float dry = smoothstep(-20.0, 160.0, h) * 0.3;
	float covered = (1.0 - exposure) * smoothstep(0.38, 0.62, mottle + (fleck - 0.5) * 0.35 - dry + 0.12);
	float rugged = max(smoothstep(0.12, 0.30, steep), smoothstep(30.0, 120.0, h) * smoothstep(450.0, 700.0, length(v_world.xz)));
	float rockiness = 1.0 - mix(1.0 - smoothstep(0.26, 0.46, steep + (macro - 0.5) * 0.18), covered, rugged);
	float g = 0.0;
	if (garden_disc.w > 0.0) {
		g = garden_disc.w * smoothstep(garden_disc.z, garden_disc.z * 0.55, length(v_world.xz - garden_disc.xy));
		rockiness *= 1.0 - g;
		// The near moss detail reads as grey grit up close; tended ground leans to a soft lit lawn.
		moss = mix(moss, moss_mean * vec3(1.25, 1.3, 0.92) * (0.9 + 0.2 * fleck), g * 0.8);
	}
	// Escarpment ledges (vertex colour g: 1 = shelf top, 0.5 = riser and lip; 0 = all other terrain):
	// lit grass tops and shaded rock risers, so the shelves read 15+ L* apart (review 13).
	float ledge_top = smoothstep(0.75, 1.0, COLOR.g);
	float ledge_riser = smoothstep(0.25, 0.5, COLOR.g) * (1.0 - ledge_top);
	rockiness = mix(rockiness, 0.0, ledge_top);
	rockiness = mix(rockiness, 1.0, ledge_riser);
	// Light, sun-bleached grass on the shelf tops (review 14: tops sat darker than risers at sat 0.75).
	// Face grass keeps the rich olive; the shelf tops are that colour desaturated by ledge_desat
	// (review 22: tops C*39 against a target of 18 while the face grass should stay rich).
	vec3 face_moss = mix(moss_mean, vec3(dot(moss_mean, vec3(0.33))), 0.2) * ledge_grass * (1.0 - 0.5 * ledge_fleck + ledge_fleck * fleck);
	vec3 ledge_moss = mix(face_moss, vec3(dot(face_moss, vec3(0.3, 0.59, 0.11))), ledge_desat);
	moss = mix(moss, ledge_moss, ledge_top);
	if (face_grass_disc.w > 0.0) {
		float fg = face_grass_disc.w * smoothstep(face_grass_disc.z, face_grass_disc.z * 0.6, length(v_world.xz - face_grass_disc.xy));
		fg *= (1.0 - ledge_riser) * (1.0 - clamp(COLOR.r, 0.0, 1.0));
		// Slightly darker than the shelf tops (the slope turns from the sky), with mottled bare patches.
		rockiness = mix(rockiness, rockiness * smoothstep(0.62, 0.8, mottle) * 0.6, fg);
		// Varied, not flat (review 21: an untextured olive wall): mottled lighter and darker swathes.
		moss = mix(moss, face_moss * (0.6 + 0.55 * smoothstep(0.35, 0.65, mottle) + 0.3 * (fleck - 0.5)), fg * (1.0 - ledge_top));
	}
	vec3 albedo = mix(moss, rock, rockiness);
	albedo *= mix(vec3(1.0), ledge_riser_tint * ledge_riser_dim, ledge_riser);
	albedo *= 0.88 + 0.24 * macro;
	vec3 fill = vec3(0.0);
	float targeted = focus * rockiness;
	if (targeted > 0.0) {
		float ledge = smoothstep(0.35, 0.8, n.y) * smoothstep(0.45, 0.7, fbm(v_world.xz * 0.04 + h * 0.02));
		albedo = mix(albedo, mix(moss_mean, vec3(0.55, 0.60, 0.45), 0.4), ledge * 0.45 * rock_breakup * targeted);
		vec3 lit_n = n;
		if (rock_relief > 0.0) {
			vec3 bump = vec3(fbm(v_world.zy * 0.08) - 0.5, fbm(v_world.xz * 0.08 + 4.0) - 0.5, fbm(v_world.xy * 0.08 + 9.0) - 0.5);
			lit_n = normalize(n + bump * rock_relief * targeted);
			NORMAL = normalize((VIEW_MATRIX * vec4(lit_n, 0.0)).xyz);
		}
		float away = 1.0 - clamp(dot(lit_n, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
		// Daylight sky bounce only: it fades out at night so the cliff never self-lights.
		fill = albedo * rock_fill_tint * rock_fill * targeted * away * mix(1.0, 0.05, night);
	}
	// Outside the focus region, a weaker daylight sky bounce on rock faces turned from the sun: the
	// clearer fog left midground mounds and cliffs as value holes (vista mound L*22.7, review 04).
	if (focus < 1.0 && rockiness > 0.0) {
		float away_o = 1.0 - clamp(dot(n, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
		fill += albedo * rock_fill_tint * 2.6 * rockiness * (1.0 - focus) * (0.35 + 0.65 * away_o) * (1.0 - night);
	}
	// Riparian band (vertex colour r, prototype stream and plunge pool only): wet gravel and
	// boulders on the eroded banks, darker toward the water; 0 elsewhere (no change).
	float riparian = COLOR.r;
	if (riparian > 0.0) {
		float stones = fbm(v_world.xz * 0.35);
		// Darker, cooler wet cobbles with dark boulders: the paler gravel read as a dry road from the vista.
		vec3 gravel = mix(vec3(0.09, 0.10, 0.10), vec3(0.21, 0.21, 0.20), smoothstep(0.35, 0.7, stones));
		gravel = mix(gravel, vec3(0.06, 0.065, 0.065), smoothstep(0.6, 0.72, fbm(v_world.xz * 0.11 + 5.1)) * 0.75);
		gravel *= mix(0.7, 1.0, smoothstep(0.85, 0.3, riparian));
		albedo = mix(albedo, gravel, smoothstep(0.0, 0.6, riparian) * 0.9);
		rockiness = max(rockiness, riparian * 0.6);
	}
	if (debug_unlit) {
		EMISSION = albedo;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = albedo;
		EMISSION = fill + soft_daylight(n, albedo, dist);
		// Shelf tops catch open skylight the low back sun never gives them (review 14: tops sat at or
		// below their risers, L*31 vs 32).
		EMISSION += albedo * ledge_top * ledge_fill * (1.0 - night) * (1.0 - 0.5 * rain);
		EMISSION += albedo * garden_fill * g * (1.0 - wet) * (1.0 - night) * (1.0 - 0.5 * rain);
		if (near_fill_disc.w > 0.0) EMISSION += albedo * near_fill_disc.w * smoothstep(near_fill_disc.z, near_fill_disc.z * 0.4, length(v_world.xz - near_fill_disc.xy)) * (1.0 - night) * (1.0 - 0.5 * rain);
	}
	ROUGHNESS = mix(mix(0.95, 0.82, rockiness), 0.55, wet_margin * (1.0 - rockiness));
	SPECULAR = mix(0.12, 0.25, wet_margin * (1.0 - rockiness));
}
