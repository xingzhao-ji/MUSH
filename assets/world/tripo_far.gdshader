shader_type spatial;
render_mode cull_back;
// Far image-to-3D landforms (concept-1 vista's distant ring): tripo_prop with its own haze, so layers
// kilometres out keep their forms under the depth fog's 95% cap. Keep in step with tripo_prop.gdshader.
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
varying float world_y;
varying vec2 world_xz;
// Own haze: fog colour (linear) and amount lerped from haze.x at range.x to haze.y at range.y (m from the eye).
uniform vec3 haze_color = vec3(0.6, 0.55, 0.75);
uniform vec2 haze = vec2(0.4, 0.8);
uniform vec2 haze_range = vec2(2000.0, 8000.0);

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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
		float radius_fraction = length(world_xz - tree_center) / max(tree_radius, 0.001);
		float normal_y = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		float down = 1.0 - smoothstep(-0.6, -0.12, normal_y);
		float under_surface = down * step(under_min_y, world_y) * smoothstep(0.40, 0.52, height_fraction);
		float cap_top = smoothstep(0.60, 0.70, height_fraction) * smoothstep(-0.1, 0.45, normal_y);
		float vein = smoothstep(0.02, 0.22, c.r - c.b) * smoothstep(0.3, 0.65, c.r);
		float core = 1.0 - smoothstep(0.18, 0.90, radius_fraction);
		float detail = clamp(dot(c, vec3(0.3, 0.55, 0.15)) / 0.28, 0.45, 1.45);
		// Linear lilac palettes retain the texture's relief and a share of its original colour.
		vec3 bark = mix(c, vec3(0.48, 0.36, 0.62) * detail, 0.78);
		vec3 cap = mix(c, vec3(0.48, 0.35, 0.69) * detail, 0.76);
		vec3 violet = vec3(0.270, 0.147, 0.807) * clamp(mx / 0.7, 0.45, 1.2);
		vec3 underside = mix(violet, under_color * mx, vein * core);
		vec3 tree_color = mix(bark, cap, cap_top);
		tree_color = mix(tree_color, mix(c, underside, 0.85), under_surface);
		ALBEDO = mix(ALBEDO, clamp(tree_color, vec3(0.0), vec3(1.0)) * base_tint * tint, palette);
		// Soft coloured fill keeps the bark legible under the blue night key; no white fill.
		vec3 tree_emission = mix(bark, cap, cap_top) * mix(0.11, 0.075, night) * (1.0 - under_surface);
		tree_emission += violet * mix(0.025, 0.04, night) * under_surface;
		// The same texture veins glow near the trunk and yield to violet toward the cap rim.
		tree_emission += under_color * under_glow * under_surface * vein * mx * (0.06 + 1.14 * core);
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
	FOG = vec4(haze_color, mix(haze.x, haze.y, smoothstep(haze_range.x, haze_range.y, length(VERTEX))));
}
