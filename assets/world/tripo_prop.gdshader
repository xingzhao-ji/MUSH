shader_type spatial;
render_mode cull_back;
// Image-to-3D props (Tripo Studio, delit PBR textures): the textures as imported, a scene tint that
// follows night and rain, and warm light from the texture's own lit areas (window glass, lantern
// panes, gold gills): bright, saturated, red-over-green-over-blue texels emit. Presentation only.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec3 tint = vec3(1.0);
uniform vec3 base_tint = vec3(1.0);
uniform float desat = 0.0;
uniform float glow = 1.0;
uniform float glow_floor = 0.6;
// Cool glow (luminous petals and cores): bright texels with blue over red emit; 0 = off.
uniform float cool_glow = 0.0;
// Pale self-light over the whole bloom (hero lilies by day: the goal's lilies are the brightest, palest
// things in the lower frame); 0 = off.
uniform float pale_glow = 0.0;
// Warm underside branches: down faces above under_min_y, masked by peach texels.
// Red-over-blue catches the model's pink-peach veins; violet gaps stay unlit. 0 = off.
uniform vec3 under_color = vec3(1.0, 0.62, 0.3);
uniform float under_glow = 0.0;
uniform float under_min_y = -100000.0;
// Optional C1 tree palette. Dimensions are the installed model's world-space bounds (metres).
// Zero preserves the ordinary prop path, including its original emission and underside treatment.
uniform float tree_palette = 0.0;
uniform float tree_base_y = 0.0;
uniform float tree_height = 1.0;
uniform vec2 tree_center = vec2(0.0);
uniform float tree_radius = 1.0;
uniform float tree_night = 0.0;
// M9 (ChatGPT checkpoint 10): a darker outer cap, a broader gold underside, fine branching at the
// trunk-to-cap join, violet-blue vein highlights and bioluminescent specks. Zero keeps the M8 look.
uniform float cap_shade = 1.0;
uniform float gold_spread = 0.0;
uniform float fine_branch = 0.0;
uniform vec3 vein_cool = vec3(0.342, 0.192, 0.807);
uniform float vein_cool_glow = 0.0;
uniform float sparkle = 0.0;
uniform float sparkle_cell = 12.0;
// Darkens the branch geometry between trunk and cap (side faces), so the glowing gills read between
// darker limbs as in the concept rather than pale lavender limbs over a pale membrane.
uniform float branch_dark = 0.0;
// M10 (Fable review, concept-1 samples: cap #916C97 mauve, rim #BD9DAC rose, trunk #DFB1B7 glowing): palette tones,
// a rose rim glow and warm light along the trunk's veins. Defaults keep the M9 look.
uniform vec3 cap_tone = vec3(0.48, 0.35, 0.69);
uniform vec3 bark_tone = vec3(0.48, 0.36, 0.62);
uniform vec3 rim_color = vec3(0.807, 0.392, 0.578);
uniform float rim_glow = 0.0;
uniform float trunk_glow = 0.0;
// M11c (Fable: concept-1's cap top reads sunset pink #E39392, rim #F1BBD5; ours cool lavender): upward cap faces mix
// toward cap_sun_color, a view-rim glow in cap_rim_color, and a little sunset emission on the cap top. 0 = off.
uniform vec3 cap_sun_color = vec3(0.693, 0.352, 0.434);
uniform float cap_sun_mix = 0.0;
uniform float cap_sun_glow = 0.0;
uniform vec3 cap_rim_color = vec3(0.880, 0.497, 0.665);
uniform float cap_rim_glow = 0.0;
// Built stone (concept-1's viaducts): world-metre courses and joints with a per-block tone, warm light on
// up-facing ledges (deck, pier caps) and darker arch soffits, so a distant span keeps its masonry read
// instead of one flat shaded face. Off at the defaults.
uniform float stone_relief = 0.0;
uniform vec2 stone_block = vec2(6.0, 2.8);
uniform vec3 ledge_color = vec3(0.95, 0.62, 0.32);
uniform float ledge_glow = 0.0;
uniform float soffit_dark = 0.0;
// Sky bounce on the masonry (backlit faces otherwise fall to the haze colour) and a lit deck band:
// cornice = (deck top y in world metres, band depth); off while its depth is 0.
uniform float stone_fill = 0.0;
uniform vec2 cornice = vec2(0.0, 0.0);
varying float world_y;
varying vec2 world_xz;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// Antialiased gills follow the installed cap radius, so scaling never changes their density.
// Fine branches fade when their period becomes subpixel instead of flickering on distant trees.
float c1_gill_line(float phase, float width) {
	float footprint = fwidth(phase);
	float aa = clamp(footprint * 0.55, 0.012, 0.40);
	return (1.0 - smoothstep(width - aa, width + aa, abs(sin(phase))))
		* (1.0 - smoothstep(0.9, 2.5, footprint));
}

// Sparse specks on a 3D cell grid (world metres): one candidate per cell, kept when its hash clears
// 1 - density; antialiased and faded once a speck falls well under a pixel.
float c1_speck(vec3 p, float cell, float density) {
	// A tilted lattice, so the specks do not line up in rings where the cap crosses its layers.
	vec3 g = mat3(vec3(0.80, 0.36, -0.48), vec3(-0.28, 0.93, 0.24), vec3(0.53, -0.08, 0.84)) * p / cell;
	vec3 id = floor(g);
	vec3 f = fract(g) - 0.5;
	float h = fract(sin(dot(id, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	vec3 o = vec3(fract(h * 17.0), fract(h * 31.0), fract(h * 53.0)) - 0.5;
	float d = length(f - o * 0.55);
	float aa = clamp(fwidth(d), 0.002, 0.5);
	float r = 0.10 + 0.06 * fract(h * 11.0);
	float level = 0.35 + 0.65 * fract(h * 23.0);
	return level * step(1.0 - density, fract(h * 7.0)) * (1.0 - smoothstep(r - aa, r + aa, d)) * (1.0 - smoothstep(0.25, 0.6, aa));
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 cc = mix(c, vec3(dot(c, vec3(0.3, 0.55, 0.15))), desat);
	ALBEDO = cc * base_tint * tint;
	ROUGHNESS = clamp(texture(rough_tex, UV).g, 0.35, 1.0);
	METALLIC = 0.0;
	if (has_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float warm = smoothstep(glow_floor, glow_floor + 0.25, c.r) * smoothstep(0.35, 0.6, sat) * smoothstep(-0.02, 0.06, c.g - c.b) * smoothstep(0.28, 0.5, c.g);
	EMISSION = c * warm * glow;
	// Cores only: blue-white/cyan texels (green over red); lavender petals (red over green) stay lit material.
	float cool = smoothstep(0.55, 0.85, c.b) * smoothstep(0.0, 0.08, c.g - c.r);
	EMISSION += c * cool * cool_glow;
	// Petals only (bright texels), lifted toward white so they read pale, not lavender.
	EMISSION += mix(cc, vec3(1.0), 0.45) * smoothstep(0.3, 0.6, mx) * pale_glow * base_tint * tint;
	if (tree_palette > 0.0) {
		float palette = clamp(tree_palette, 0.0, 1.0);
		float night = clamp(tree_night, 0.0, 1.0);
		float height_fraction = (world_y - tree_base_y) / max(tree_height, 0.001);
		vec2 cap_position = (world_xz - tree_center) / max(tree_radius, 0.001);
		float radius_fraction = length(cap_position);
		float normal_y = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		float down = 1.0 - smoothstep(-0.6, -0.12, normal_y);
		float under_surface = down * step(under_min_y, world_y) * smoothstep(0.40, 0.52, height_fraction);
		float cap_top = smoothstep(0.60, 0.70, height_fraction) * smoothstep(-0.1, 0.45, normal_y);
		float vein = smoothstep(0.02, 0.22, c.r - c.b) * smoothstep(0.3, 0.65, c.r);
		float core = 1.0 - smoothstep(0.18 + 0.10 * gold_spread, 0.90 + 0.12 * gold_spread, radius_fraction);
		float detail = clamp(dot(c, vec3(0.3, 0.55, 0.15)) / 0.28, 0.45, 1.45);
		// Linear lilac palettes retain the texture's relief and a share of its original colour.
		vec3 bark = mix(c, bark_tone * detail, 0.78);
		vec3 cap = mix(c, cap_tone * detail, 0.76);
		float outer_cap = mix(1.0, cap_shade, smoothstep(0.30, 0.95, radius_fraction));
		cap *= outer_cap;
		vec3 violet = vec3(0.270, 0.147, 0.807) * clamp(mx / 0.7, 0.45, 1.2);
		// Two curved radial families split as they travel outward. The faint connective membrane
		// softens the bare-branch reading; brightest filaments stay around the trunk, not the rim.
		float angle = atan(cap_position.y, cap_position.x + 0.00001);
		float warp = sin(angle * 7.0 + radius_fraction * 8.0) * 0.70
			+ sin(angle * 13.0 - radius_fraction * 5.0) * 0.24;
		float main_gill = c1_gill_line(angle * 31.0 + radius_fraction * 7.0 + warp, 0.105);
		float fine_gill = c1_gill_line(angle * 59.0 - radius_fraction * 11.0 + warp * 1.6, 0.075)
			* smoothstep(0.25, 0.65, radius_fraction);
		float gills = max(main_gill * 0.78, fine_gill * 0.45)
			* smoothstep(0.08, 0.20, radius_fraction) * (1.0 - smoothstep(0.88, 1.01, radius_fraction));
		// Fine branching where the trunk opens into the cap: a dense third family fading by mid-radius.
		float branch = c1_gill_line(angle * 97.0 + radius_fraction * 23.0 + warp * 2.3, 0.07)
			* smoothstep(0.04, 0.10, radius_fraction) * (1.0 - smoothstep(0.22, 0.48, radius_fraction)) * fine_branch;
		gills = max(gills, branch * 0.85);
		float gold_mask = clamp(vein * core + gills * (0.24 + 0.56 * core) + (0.10 + 0.16 * gold_spread) * core, 0.0, 1.0);
		vec3 underside = mix(violet, under_color * clamp(mx, 0.45, 1.0), gold_mask);
		float sun_face = smoothstep(0.15, 0.85, normal_y) * cap_top;
		cap = mix(cap, cap_sun_color * clamp(detail, 0.7, 1.25), sun_face * cap_sun_mix);
		vec3 tree_color = mix(bark, cap, cap_top);
		tree_color = mix(tree_color, mix(c, underside, 0.85), under_surface);
		float branch_zone = smoothstep(0.30, 0.44, height_fraction) * (1.0 - smoothstep(0.60, 0.67, height_fraction))
			* (1.0 - under_surface) * (1.0 - cap_top);
		tree_color *= 1.0 - branch_dark * branch_zone;
		ALBEDO = mix(ALBEDO, clamp(tree_color, vec3(0.0), vec3(1.0)) * base_tint * tint, palette);
		// Soft coloured fill keeps the bark legible under the blue night key; no white fill.
		vec3 tree_emission = mix(bark, cap, cap_top) * mix(0.11, 0.075, night) * (1.0 - under_surface) * (1.0 - branch_dark * branch_zone);
		// Warm light caught along the limbs' texture veins under the glowing gills.
		tree_emission += under_color * under_glow * branch_zone * vein * mx * 0.6 * branch_dark;
		tree_emission += violet * mix(0.025, 0.04, night) * under_surface;
		// Imported large veins and finer gills share one orange-gold source. The low membrane
		// contribution is coloured and radius-limited, preserving violet gaps and texture relief.
		float warm_energy = vein * mx * (0.06 + 1.00 * core)
			+ gills * (0.10 + 0.58 * core) + (0.045 + 0.035 * gold_spread) * core * clamp(detail, 0.6, 1.2);
		tree_emission += under_color * under_glow * under_surface * warm_energy;
		float view_rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * cap_top;
		tree_emission += cap_rim_color * cap_rim_glow * view_rim * (1.0 - night * 0.5);
		tree_emission += cap_sun_color * cap_sun_glow * sun_face * (1.0 - night);
		// Rose rim: the cap's outer band and edge (top and underside) glow, as concept-1's membrane edge does.
		float rim = smoothstep(0.93, 0.995, radius_fraction) * smoothstep(0.50, 0.58, height_fraction);
		tree_emission += rim_color * rim_glow * rim * (0.55 + 0.45 * mx);
		// Warm light along the trunk's texture veins below the cap.
		float trunk_zone = (1.0 - smoothstep(0.50, 0.60, height_fraction)) * (1.0 - under_surface) * (1.0 - cap_top);
		tree_emission += under_color * trunk_glow * trunk_zone * (0.25 * vein + 0.12 * smoothstep(0.35, 0.8, mx));
		// Violet-blue highlights on the outer fine gills, where the gold thins toward the rim.
		tree_emission += vein_cool * vein_cool_glow * under_surface * fine_gill * (1.0 - 0.75 * core)
			* (1.0 - smoothstep(0.88, 1.01, radius_fraction));
		if (sparkle > 0.0) {
			vec3 wp = vec3(world_xz.x, world_y, world_xz.y);
			float on_cap = smoothstep(0.55, 0.62, height_fraction);
			// Denser toward the rim, as the concept's cap lights gather at its edge.
			float s_top = c1_speck(wp, sparkle_cell, 0.18 + 0.30 * smoothstep(0.45, 0.95, radius_fraction)) * cap_top * on_cap;
			float s_under = c1_speck(wp + 3.7, sparkle_cell * 0.8, 0.5) * under_surface;
			tree_emission += vec3(1.0, 0.70, 0.62) * s_top * sparkle * mix(0.6, 1.6, night);
			tree_emission += mix(vein_cool, vec3(0.85, 0.9, 1.0), 0.45) * s_under * sparkle * 1.3 * mix(1.0, 1.6, night);
		}
		// Keep the imported bright flecks, without the old broad warm emission washing the cap out.
		tree_emission += EMISSION * mix(0.15, 0.08, under_surface);
		tree_emission += c * smoothstep(0.78, 0.95, mx) * smoothstep(0.05, 0.24, c.b - c.r) * cap_top * 0.045;
		EMISSION = mix(EMISSION, tree_emission, palette);
	} else if (under_glow > 0.0) {
		float down = 1.0 - smoothstep(-0.6, -0.12, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
		float vein = smoothstep(0.02, 0.22, c.r - c.b) * smoothstep(0.3, 0.65, c.r);
		float underside = down * step(under_min_y, world_y) * vein;
		// Retain texture value variation while shifting peach branches toward amber.
		ALBEDO = mix(ALBEDO, under_color * mx * tint, underside * 0.65);
		EMISSION += under_color * under_glow * underside * mx;
	}
	if (stone_relief > 0.0 || ledge_glow > 0.0 || soffit_dark > 0.0 || stone_fill > 0.0) {
		vec3 n_world = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float along = abs(n_world.x) > abs(n_world.z) ? world_xz.y : world_xz.x;
		float course = world_y / stone_block.y;
		float row = floor(course);
		float run = along / stone_block.x + 0.5 * mod(row, 2.0);
		vec2 cell = vec2(fract(run), fract(course));
		vec2 foot = fwidth(vec2(run, course));
		float joint = max(1.0 - smoothstep(0.0, max(foot.x * 1.5, 0.05), min(cell.x, 1.0 - cell.x)),
			1.0 - smoothstep(0.0, max(foot.y * 1.5, 0.07), min(cell.y, 1.0 - cell.y)));
		joint *= 1.0 - smoothstep(0.35, 0.9, max(foot.x, foot.y));
		float block = fract(sin(dot(vec2(floor(run), row), vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO *= mix(1.0, mix(0.84, 1.12, block) * (1.0 - 0.5 * joint), stone_relief);
		ALBEDO *= 1.0 - soffit_dark * smoothstep(0.35, 0.8, -n_world.y);
		EMISSION += ledge_color * ledge_glow * smoothstep(0.55, 0.9, n_world.y);
		EMISSION += ALBEDO * stone_fill * (1.0 - smoothstep(0.35, 0.8, -n_world.y));
		if (cornice.y > 0.0) {
			EMISSION += ledge_color * ledge_glow * smoothstep(cornice.x - cornice.y, cornice.x - cornice.y * 0.3, world_y)
				* (1.0 - smoothstep(cornice.x + 0.5, cornice.x + 2.0, world_y)) * (1.0 - 0.6 * joint);
		}
	}
}
