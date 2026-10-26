shader_type spatial;
render_mode cull_back;
// West Wall granite (prototype geology landmark). UV = (metres along the toe, metres above the
// toe); COLOR.r = 1 on the sheer face, 0 on the crest; COLOR.g = wetness near the falls;
// COLOR.b = height fraction up the face; COLOR.a = drip (just below a ledge lip).
// Pale warm-grey slabs, faint exfoliation sheets, dark vertical water streaks hanging from the
// crest (strongest around the falls), and dark vegetation only on ledges and the crest.
uniform float night = 0.0;
uniform float rain = 0.0;
// Snow on up-facing rock above this height (world metres).
uniform float snowline = 520.0;
// For meshes without wall data (the ice peak): map along/height from world position.
uniform bool world_mapped = false;
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
	float slab = fbm(vec2(s * 0.004, h * 0.003));
	vec3 rock = mix(vec3(0.30, 0.30, 0.30), vec3(0.48, 0.46, 0.43), smoothstep(0.25, 0.75, slab));
	// Fresh spall scars: sharp-edged paler, warmer patches where sheets broke away.
	float scar = smoothstep(0.58, 0.62, fbm(vec2(s * 0.005, h * 0.006) + 7.3)) * face;
	rock = mix(rock, vec3(0.70, 0.64, 0.55), scar * 0.6);
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
	float snow = smoothstep(snowline - 40.0, snowline + 60.0, v_world.y + (fbm(v_world.xz * 0.01) - 0.5) * 120.0) * smoothstep(world_mapped ? 0.62 : 0.55, world_mapped ? 0.86 : 0.8, normalize(v_up).y);
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
	ROUGHNESS = mix(mix(0.84, 0.6, max(rain, wet * face * 0.5)), 0.7, snow);
	SPECULAR = 0.3;
}
