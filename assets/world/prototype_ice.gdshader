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
	vec3 glacier = mix(vec3(0.58, 0.70, 0.78), vec3(0.93, 0.95, 0.98), snow);
	glacier = mix(glacier, vec3(0.10, 0.22, 0.34), crevasse * 0.8);
	float steep = 1.0 - smoothstep(0.35, 0.75, abs(normalize(v_up).y));
	glacier = mix(glacier, vec3(0.30, 0.47, 0.60), steep * 0.8 * (1.0 - snow * 0.7));
	// Blue ice is far darker than snow (albedo ~0.3-0.5, not 0.6-0.8): the brighter values read as a
	// glowing cyan cliff at night. Terminus cliff: blue ice split by vertical fracture lines between serac columns.
	float fracture = smoothstep(0.86, 0.97, abs(fract(UV.y * 9.0 + fbm(vec2(UV.y * 3.0, 1.7)) * 0.8) - 0.5) * 2.0);
	vec3 cliff = vec3(0.28, 0.45, 0.60) * (0.85 + 0.3 * fbm(vec2(UV.y * 8.0, 3.0)));
	cliff = mix(cliff, vec3(0.08, 0.18, 0.30), fracture * 0.75);
	glacier = mix(glacier, cliff, COLOR.r);
	glacier = mix(glacier, vec3(0.40, 0.38, 0.36) * (0.8 + 0.4 * fbm(vec2(u * 30.0, UV.y * 9.0))), COLOR.g * 0.75);
	// Hanging glacier draped over the lip (COLOR.b; UV.x 1..2 down the drape): pale blue-white ice
	// broken by bowed transverse crevasse bands, deep blue in the cracks, bluer and thinner toward
	// the ragged lower edge.
	if (COLOR.b > 0.0) {
		float dd = clamp(u - 1.0, 0.0, 1.0);
		float bow = UV.y * UV.y * 0.9 + fbm(vec2(UV.y * 3.0, dd * 2.0 + 4.0)) * 0.8;
		float cb = abs(fract(dd * 6.5 + bow) - 0.5) * 2.0;
		float crack = smoothstep(0.78, 0.95, cb) * smoothstep(0.35, 0.65, fbm(vec2(UV.y * 5.0, dd * 9.0 + 2.0)));
		vec3 drape = mix(vec3(0.74, 0.84, 0.94), vec3(0.52, 0.68, 0.84), smoothstep(0.4, 1.0, dd));
		drape *= 0.9 + 0.18 * fbm(vec2(UV.y * 11.0, dd * 14.0));
		drape = mix(drape, vec3(0.16, 0.30, 0.48), crack * 0.85);
		glacier = mix(glacier, drape, COLOR.b);
		// Glacier ice glows blue-white even in shade (light scattered through it): the drape sits on
		// the gully's sun-averted wall and read as a lavender slab (sweep 142241).
		EMISSION = drape * vec3(0.55, 0.68, 0.85) * 0.55 * (1.0 - crack * 0.7) * COLOR.b * (1.0 - night) * (1.0 - 0.5 * rain);
	}
	// Night: the blue moonlight on blue ice doubled the saturation and the serac cliff read as a
	// glowing cyan panel; ice goes toward neutral grey-blue and loses most of its gloss.
	float ice_lum = dot(glacier, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(glacier, vec3(ice_lum) * vec3(0.66, 0.68, 0.78), night * 0.75);
	// The serac cliff faces the low sun: at roughness 0.35 / specular 0.45 it clipped to white (review 04).
	ROUGHNESS = mix(mix(mix(0.35, 0.75, snow), 0.6, COLOR.r), 0.7, night);
	SPECULAR = mix(mix(0.45, 0.22, COLOR.r), 0.2, night);
	if (debug_view == 1) { EMISSION = ALBEDO; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 2) { EMISSION = normalize(v_up) * 0.5 + 0.5; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 3) { ALBEDO = vec3(0.5); }
	else if (debug_view == 4) { EMISSION = vec3(0.0, 1.0, 1.0); ALBEDO = vec3(0.0); SPECULAR = 0.0; }
}
