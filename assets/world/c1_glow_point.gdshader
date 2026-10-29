shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// M10b: no engine fog (on an additive quad the fog colour is added over the whole square: with the near-linear C1 fog
// the distant points read as white squares, Fable's "sugar cubes"); dimmed with distance here instead.
// Concept-1 valley glow points (lanterns, lit windows, glowing mushrooms on the cliff crowns): camera-facing soft
// discs per MultiMesh instance, coloured by the instance colour, brighter at night. Presentation only.
uniform float energy = 1.5;
// M15b: core and halo falloff (defaults are the valley glow points; the floating spores use a softer, wider halo)
uniform float core_k = 14.0;
uniform float halo_amt = 0.35;
uniform float halo_k = 3.5;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = dot(d, d);
	float core = exp(-r * core_k);
	float halo = exp(-r * halo_k) * halo_amt;
	ALBEDO = COLOR.rgb * (core + halo) * energy * mix(1.0, 0.5, smoothstep(300.0, 2600.0, length(VERTEX)));
}
