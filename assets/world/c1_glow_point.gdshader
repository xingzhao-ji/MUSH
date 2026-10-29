shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Concept-1 valley glow points (lanterns, lit windows, glowing mushrooms on the cliff crowns): camera-facing soft
// discs per MultiMesh instance, coloured by the instance colour, brighter at night. Presentation only.
uniform float energy = 1.5;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = dot(d, d);
	float core = exp(-r * 14.0);
	float halo = exp(-r * 3.5) * 0.35;
	ALBEDO = COLOR.rgb * (core + halo) * energy;
}
