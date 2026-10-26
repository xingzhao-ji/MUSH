shader_type spatial;
render_mode cull_disabled;
// Ice tongue (prototype geology landmark), opaque. UV.x along the flow (0 inside the peak's
// flank .. 1 at the snout), UV.y across (-1..1); COLOR.r = 1 on the ice cliff, COLOR.g = lateral
// moraine. Flat-shaded facets. Snow-covered upstream, transverse crevasses where the tongue
// steepens, blue on steep serac faces and the cliff, dark rubble on the moraines.
uniform float night = 0.0;
uniform float rain = 0.0;
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
	glacier = mix(glacier, vec3(0.42, 0.63, 0.78) * (0.85 + 0.3 * fbm(vec2(UV.y * 8.0, 3.0))), COLOR.r);
	glacier = mix(glacier, vec3(0.30, 0.28, 0.26) * (0.8 + 0.4 * fbm(vec2(u * 30.0, UV.y * 9.0))), COLOR.g * 0.9);
	ALBEDO = mix(glacier, glacier * vec3(0.6, 0.65, 0.9), night * 0.5);
	ROUGHNESS = mix(0.35, 0.75, snow);
	SPECULAR = 0.45;
}
