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
uniform float glow = 1.0;
uniform float glow_floor = 0.6;
// Cool glow (luminous petals and cores): bright texels with blue over red emit; 0 = off.
uniform float cool_glow = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = c * tint;
	ROUGHNESS = clamp(texture(rough_tex, UV).g, 0.35, 1.0);
	METALLIC = 0.0;
	if (has_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float warm = smoothstep(glow_floor, glow_floor + 0.25, c.r) * smoothstep(0.35, 0.6, sat) * smoothstep(-0.02, 0.06, c.g - c.b) * smoothstep(0.28, 0.5, c.g);
	EMISSION = c * warm * glow;
	float cool = smoothstep(0.62, 0.92, mx) * smoothstep(-0.02, 0.08, c.b - c.r);
	EMISSION += c * cool * cool_glow;
}
