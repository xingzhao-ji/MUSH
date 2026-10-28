shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// Shore reeds and cattails (vista refuge): vertex-colour blades and heads. The golden key sits in
// front of the vista, so the reeds are seen from their shaded side; a self-fill from their own
// colour and a warm transmission keep them reading as green/tan reeds with brown heads instead of
// black spikes against the bright lake (review 15: RGB 51,49,31). apply_look sets tint and fill.
uniform vec3 tint : source_color = vec3(1.0);
uniform float fill = 0.35;
uniform float backlight = 0.45;
void fragment() {
	vec3 c = COLOR.rgb * tint;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	EMISSION = c * fill;
	BACKLIGHT = c * backlight;
}
