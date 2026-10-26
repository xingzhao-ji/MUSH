shader_type spatial;
render_mode cull_back;
// West Wall granite (prototype geology landmark). UV = (metres along the toe, metres above the
// toe); COLOR.r = 1 on the sheer face, 0 on the crest; COLOR.g = wetness near the falls;
// COLOR.b = height fraction up the face; COLOR.a = drip (just below a ledge lip);
// UV2.x = facet panel tone (0 weathered dark .. 1 freshly spalled pale), UV2.y = occlusion (fracture
// recess or geometric concavity: gullies, dihedrals, bench undersides).
// Pale warm-grey slabs, faint exfoliation sheets, dark vertical water streaks hanging from the
// crest (strongest around the falls), and dark vegetation only on ledges and the crest.
uniform float night = 0.0;
uniform float rain = 0.0;
// Snow on up-facing rock above this height (world metres).
uniform float snowline = 520.0;
// For meshes without wall data (the ice peak): map along/height from world position.
uniform bool world_mapped = false;
// Capture-only diagnosis (0 = final): 1 unlit albedo, 2 world normal, 3 grey lit, 4 mask.
uniform int debug_view = 0;
varying vec3 v_world;
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
// Worley cells: x = distance to the nearest feature, y = to the second nearest, z = cell id.
vec3 worley(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + vec2(hash21(i + g), hash21(i + g + 17.3)) - f;
			float d = dot(r, r);
			if (d < f1) { f2 = f1; f1 = d; id = hash21(i + g + 5.1); }
			else if (d < f2) { f2 = d; }
		}
	}
	return vec3(sqrt(f1), sqrt(f2), id);
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float s = world_mapped ? v_world.x + v_world.z : UV.x;
	float h = world_mapped ? v_world.y + 100.0 : UV.y;
	float face = world_mapped ? 1.0 - smoothstep(0.5, 0.8, normalize(v_up).y) : COLOR.r;
	float wet = world_mapped ? 0.0 : COLOR.g;
	float rise = world_mapped ? clamp((v_world.y + 80.0) / 1000.0, 0.0, 1.0) : COLOR.b;
	// Slabs: broad tonal panels, warmer and lighter where fresh rock spalled off.
	// Panel tone: each broad facet is weathered (dark, cool) or freshly spalled (pale, warm),
	// with only a slow tonal drift inside it; fracture recesses are dark and cool.
	float tone = world_mapped ? 0.25 : UV2.x;
	float recess = world_mapped ? 0.0 : UV2.y;
	float slab = fbm(vec2(s * 0.004, h * 0.003));
	vec3 rock = mix(vec3(0.21, 0.21, 0.22), vec3(0.45, 0.42, 0.38), smoothstep(0.15, 0.9, tone)) * mix(0.9, 1.06, slab);
	rock = mix(rock, vec3(0.11, 0.12, 0.13), recess * 0.35 * face);
	// Mid-scale structure (10-80 m, the band that resolves at 0.3-1.2 km): irregular fracture
	// plates (domain-warped Worley cells, ~55 x 80 m), each with its own tone and tilt; dark
	// fracture lines along plate borders that fade in and out (fractures terminate); a few long,
	// sweeping sheeting joints, present only in places. No fixed lattice.
	vec2 warp = vec2(fbm(vec2(s * 0.004, h * 0.003)), fbm(vec2(h * 0.004, s * 0.003) + 3.1)) * 1.6;
	vec3 cell = worley(vec2(s / 55.0, h / 80.0) + warp);
	float block = cell.z;
	float block2 = hash21(vec2(cell.z * 91.7, 0.37));
	float edge = cell.y - cell.x;
	// Fractures are discontinuous: only a minority of plate borders open, leaving broad quiet planes.
	float open = smoothstep(0.56, 0.68, fbm(vec2(s * 0.009, h * 0.008) + 5.7));
	float fracture_line = (1.0 - smoothstep(0.0, max(0.05, fwidth(edge) * 1.5), edge)) * open;
	float sy = h / 90.0 + 0.8 * sin(s * 0.005) + fbm(vec2(s * 0.003, h * 0.004)) * 1.2;
	float sheet_line = (1.0 - smoothstep(0.0, max(0.03, fwidth(sy) * 1.5), min(fract(sy), 1.0 - fract(sy)))) * smoothstep(0.5, 0.65, fbm(vec2(s * 0.006, floor(sy) * 3.3)));
	float blocks = world_mapped ? 0.0 : face;
	rock *= mix(1.0, mix(0.9, 1.07, block), blocks);
	rock = mix(rock, rock * 0.42, max(fracture_line, sheet_line * 0.8) * 0.65 * blocks);
	float sheet = fbm(vec2(s * 0.01, h * 0.02 + fbm(vec2(s * 0.003, h * 0.002)) * 4.0));
	rock *= mix(0.86, 1.06, sheet);
	// Water streaks: narrow across, long downward, hanging from the crest and fading toward
	// the toe; wider and darker around the falls.
	float hang = fbm(vec2(s * 0.045, h * 0.0022));
	// Water: generic streaks stay faint; strong narrow streaks hang only below ledge lips (drip)
	// and around the falls (wet).
	float drip = world_mapped ? 0.0 : COLOR.a;
	float streak = smoothstep(0.62, 0.8, hang) * face * mix(0.2, 0.6, rise);
	streak = max(streak, drip * face * smoothstep(0.42, 0.68, fbm(vec2(s * 0.12, h * 0.01))));
	streak = max(streak, wet * face * smoothstep(0.15, 0.5, fbm(vec2(s * 0.08, h * 0.004))));
	rock = mix(rock, vec3(0.20, 0.19, 0.18), streak * 0.65);
	// Wet rock behind the falls: darker still, so the white water reads against it.
	rock = mix(rock, vec3(0.13, 0.14, 0.15), wet * face * 0.55);
	// Vegetation: ledges and the crest only (surfaces facing up).
	float up = smoothstep(0.7, 0.9, normalize(v_up).y);
	float pines = smoothstep(0.42, 0.62, fbm(v_world.xz * 0.03));
	rock = mix(rock, mix(vec3(0.24, 0.29, 0.19), vec3(0.14, 0.19, 0.13), pines), up * 0.85 * (1.0 - smoothstep(snowline - 120.0, snowline, v_world.y)));
	// Persistent alpine snow: up-facing rock above the snowline, ragged at its lower edge.
	float snow = smoothstep(snowline - 40.0, snowline + 60.0, v_world.y + (fbm(v_world.xz * 0.01) - 0.5) * 120.0) * smoothstep(world_mapped ? 0.78 : 0.55, world_mapped ? 0.93 : 0.8, normalize(v_up).y);
	rock = mix(rock, vec3(0.88, 0.91, 0.96), snow);
	// Fine grain near the viewer, faded with distance.
	float grain = vnoise(v_world.xz * 0.9 + v_world.y * 0.7);
	float near = 1.0 - smoothstep(60.0, 260.0, length(VERTEX));
	rock *= 1.0 + (grain - 0.5) * 0.08 * near;
	// Mineral speckle (dark biotite, pale feldspar), only where it can resolve.
	float speck = vnoise(v_world.xz * 3.1 + v_world.y * 2.3);
	rock = mix(rock, rock * mix(0.7, 1.2, step(0.5, speck)), smoothstep(0.82, 0.95, abs(speck - 0.5) * 2.0) * 0.4 * near);
	rock = mix(rock, rock * 0.86, rain);
	rock = mix(rock, rock * vec3(0.55, 0.58, 0.85), night * 0.6);
	ALBEDO = rock;
	// Each joint block faces slightly differently (tangent frame from the face coordinates), so
	// light breaks the face into fractured planes at mid scale.
	if (!world_mapped) {
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec2 duv1 = dFdx(UV);
		vec2 duv2 = dFdy(UV);
		vec3 dp2perp = cross(dp2, NORMAL);
		vec3 dp1perp = cross(NORMAL, dp1);
		vec3 t_along = dp2perp * duv1.x + dp1perp * duv2.x;
		vec3 t_up = dp2perp * duv1.y + dp1perp * duv2.y;
		float scale = inversesqrt(max(max(dot(t_along, t_along), dot(t_up, t_up)), 1e-12));
		NORMAL = normalize(NORMAL + (t_along * scale * (block - 0.5) * 0.55 + t_up * scale * (block2 - 0.5) * 0.4) * face);
	}
	// Wet rock (falls spray and ledge drips, or rain) is darker and glossier than dry rock.
	float wetness = max(rain * 0.6, max(wet, streak * 0.8) * face) * (1.0 - snow);
	ROUGHNESS = mix(mix(0.84, 0.28, wetness), 0.7, snow);
	SPECULAR = mix(0.3, 0.5, wetness);
	// Form shadows from the geometry's concavities: ambient and, partly, direct light.
	AO = 1.0 - recess * 0.75 * face;
	AO_LIGHT_AFFECT = 0.55;
	if (debug_view == 1) { EMISSION = ALBEDO; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 2) { EMISSION = normalize(v_up) * 0.5 + 0.5; ALBEDO = vec3(0.0); SPECULAR = 0.0; }
	else if (debug_view == 3) { ALBEDO = vec3(0.5); }
	else if (debug_view == 4) { EMISSION = vec3(1.0, 0.0, 1.0); ALBEDO = vec3(0.0); SPECULAR = 0.0; }
}
