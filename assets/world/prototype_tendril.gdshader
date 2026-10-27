shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Luminous drips hanging from the giant caps' rims (prototype; concept: glowing strands under the
// umbrella canopies). Crossed ribbons, UV.y 0 at the rim to 1 at the tip. Additive light that
// thins toward the tip and ends in a small bead; faint by day, bright at night; slow shimmer.
// Fog is disabled for the additive blend, so it fades with distance on its own.
uniform vec3 glow : source_color = vec3(0.86, 0.74, 1.0);
uniform vec3 tip_glow : source_color = vec3(1.0, 0.82, 0.62);
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float day_strength = 0.16;
uniform float night_strength = 0.9;
varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.15, 1.0, across);
	float fade = pow(1.0 - UV.y, 0.8);
	float bead = smoothstep(0.86, 0.95, UV.y) * (1.0 - smoothstep(0.95, 1.0, UV.y)) * 2.5;
	float phase = fract(sin(dot(floor(v_world.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	float pulse = 0.8 + 0.2 * sin(shimmer_time * shimmer_amount * 0.7 + phase * 6.2831);
	float dist = length(VERTEX);
	float far = exp(-dist / 1800.0);
	float k = mix(day_strength, night_strength, night) * (1.0 - 0.5 * rain) * pulse * far;
	ALBEDO = (glow * fade + tip_glow * bead) * core * k;
}
