shader_type spatial;
render_mode cull_disabled;
// Refuge kit petals (Quaternius flower sheet, desaturated toward lavender/pink/white). Lit as before by
// day; at night they glow from the blossom centre outward: emission rises with how squarely a petal faces
// the viewer, so each bloom keeps a bright heart and darker edges instead of a flat cutout (review 13/14).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow_color : source_color = vec3(0.82, 0.6, 1.0);
uniform float day_glow = 0.08;
uniform float night_glow = 0.0;
uniform float alpha_cut = 0.2;
// Rim light: low by day (0.3 blew the refuge bells out under the golden key, review 15: 6.4% above
// L*92), full at night where it carries the petal edges.
uniform float rim = 0.3;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALBEDO = t.rgb * tint;
	ROUGHNESS = 1.0;
	// As the kit material had: a soft rim, so back-lit petals stay luminous (low by day, see rim).
	RIM = rim;
	RIM_TINT = 0.8;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float heart = pow(facing, 2.5);
	EMISSION = t.rgb * glow_color * (day_glow + night_glow * (0.12 + 0.88 * heart));
}
