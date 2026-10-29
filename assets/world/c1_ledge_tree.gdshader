shader_type spatial;
render_mode cull_back, specular_disabled;
// Concept-1 ledge forest (M9): low-poly clumps and firs, instance colour x height shade (vertex colour),
// the scene tint, and the valley's own haze by distance (the depth fog is ~5% at 1 km). Presentation only.
uniform vec3 tint = vec3(1.0);
uniform vec3 haze_color = vec3(0.6, 0.55, 0.75);
uniform vec2 haze = vec2(0.05, 0.55);
uniform vec2 haze_range = vec2(450.0, 2000.0);

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 1.0;
	FOG = vec4(haze_color, mix(haze.x, haze.y, smoothstep(haze_range.x, haze_range.y, length(VERTEX))));
}
