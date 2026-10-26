shader_type spatial;
render_mode cull_disabled;
// Ice tongue (prototype geology landmark), opaque. UV.x along the flow (0 inside the peak's
// flank .. 1 at the snout), UV.y across (-1..1); COLOR.r = 1 on the ice cliff, COLOR.g = lateral
// moraine. Flat-shaded facets. Snow-covered upstream, transverse crevasses where the tongue
// steepens, blue on steep serac faces and the cliff, dark rubble on the moraines.
uniform float night = 0.0;
uniform float rain = 0.0;
// Capture-only diagnosis (0 = final): 1 unlit albedo, 2 world normal, 3 grey lit, 4 mask.
uniform int debug_view = 0;
varying vec3 v_up;

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
void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float u = UV.x;
	float warp = fbm(vec2(u * 6.0, UV.y * 2.0)) * 1.6 + UV.y * UV.y * 0.8;
	float band = abs(fract(u * 16.0 + warp) - 0.5) * 2.0;
	float crevasse = smoothstep(0.82, 0.97, band) * smoothstep(0.25, 0.6, u) * (1.0 - 0.6 * (1.0 - abs(UV.y)));
	float snow = 1.0 - smoothstep(0.2, 0.55, u);
	vec3 glacier = mix(vec3(0.72, 0.83, 0.90), vec3(0.93, 0.95, 0.98), snow);
	glacier = mix(glacier, vec3(0.20, 0.42, 0.62), crevasse * 0.8);
	float steep = 1.0 - smoothstep(0.35, 0.75, abs(normalize(v_up).y));
	glacier = mix(glacier, vec3(0.38, 0.60, 0.76), steep * 0.8 * (1.0 - snow * 0.7));
	// Terminus cliff: blue ice split by vertical fracture lines between serac columns.
	float fracture = smoothstep(0.86, 0.97, abs(fract(UV.y * 9.0 + fbm(vec2(UV.y * 3.0, 1.7)) * 0.8) - 0.5) * 2.0);
	vec3 cliff = vec3(0.40, 0.62, 0.80) * (0.85 + 0.3 * fbm(vec2(UV.y * 8.0, 3.0)));
	cliff = mix(cliff, vec3(0.12, 0.30, 0.48), fracture * 0.75);
	glacier = mix(glacier, cliff, COLOR.r);
	glacier = mix(glacier, vec3(0.30, 0.28, 0.26) * (0.8 + 0.4 * fbm(vec2(u * 30.0, UV.y * 9.0))), COLOR.g * 0.9);
	ALBEDO = mix(glacier, glacier * vec3(0.6, 0.65, 0.9), night * 0.5);
	ROUGHNESS = mix(0.35, 0.75, snow);
	SPECULAR = 0.45;
	if (debug_view == 1) { EMISSION = ALBEDO; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 2) { EMISSION = normalize(v_up) * 0.5 + 0.5; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 3) { ALBEDO = vec3(0.5); }
	else if (debug_view == 4) { EMISSION = vec3(0.0, 1.0, 1.0); ALBEDO = vec3(0.0); SPECULAR = 0.0; }
}
