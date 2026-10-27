shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled, shadows_disabled;
// Golden-hour sky glow (prototype only): an additive camera-following dome just inside the far
// plane, over the live sky. A broad warm halo around the sun and a peach horizon band that is
// strongest on the sun's side, so the sky reads as late-afternoon light instead of a flat wash.
// It only adds light over the sky (all scenery is nearer than the dome); off at night and in rain.
// It also draws the sun disc (the prototype hides the world's 120 m sun sphere by render layer).
uniform vec3 sun_dir = vec3(0.77, 0.25, -0.64);
// Direction of the warm halo and horizon band (decoupled from the key light); the disc uses sun_dir.
uniform vec3 glow_dir = vec3(0.77, 0.15, -0.64);
uniform vec3 glow_color : source_color = vec3(1.0, 0.72, 0.45);
uniform float strength = 0.35;
uniform float night = 0.0;
uniform float rain = 0.0;
// Halo falloff: 5 spread the halo over the whole upper frame (vista zenith strip L*79, consult 01
// wants 60-70 with the glow at 78-82); a tighter halo keeps the glow on the horizon.
uniform float halo_power = 5.0;
uniform float halo_gain = 0.55;
varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}
void fragment() {
	vec3 d = normalize(v_dir);
	vec3 s = normalize(glow_dir);
	float facing = max(dot(d, s), 0.0);
	float sun_facing = max(dot(d, normalize(sun_dir)), 0.0);
	float halo = pow(facing, halo_power) * halo_gain + pow(facing, 40.0) * 0.6;
	vec2 dh = normalize(d.xz + vec2(1e-5));
	vec2 sh = normalize(s.xz + vec2(1e-5));
	float side = pow(dot(dh, sh) * 0.5 + 0.5, 2.0);
	float band = exp(-max(d.y, 0.0) * 7.0) * mix(0.25, 1.0, side);
	float above = smoothstep(-0.02, 0.03, d.y);
	float k = (halo + band * 0.6) * above * strength * (1.0 - night) * (1.0 - rain);
	// Sun disc (~1.3 degrees) on the dome, so scenery in front of it occludes it (the world's own
	// 120 m sun sphere drew over the far walls once the sun moved into view).
	float disc = smoothstep(0.99970, 0.99982, sun_facing) * above * (1.0 - night) * (1.0 - rain);
	ALBEDO = glow_color * k + vec3(1.0, 0.86, 0.66) * disc * 1.6;
}
