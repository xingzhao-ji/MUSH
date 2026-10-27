shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// West Falls (prototype geology landmark). Ribbon: UV.x across (0..1), UV.y from the lip (0)
// down to the foot (1); streaks travel downward with shimmer_time (frozen under reduced motion),
// edges feather and the sheet spreads lower down. Mist: soft sheets at the foot.
uniform float shimmer_time = 0.0;
uniform float shimmer_amount = 1.0;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform bool mist = false;
// Outlet stream: UV.x across (0..1), UV.y along the channel (downstream); COLOR.r = steepness
// of the reach (more foam where it steps down); COLOR.g = 1 over the lake (fades out).
uniform bool stream = false;
// Painterly sky sheen on the stream by day (0 = previous look): seen from above, the flat reaches
// were dark clear water and the outflow broke before the lake (review 08); the concepts' streams
// read as bright ribbons mirroring the glowing sky.
uniform vec3 day_sheen = vec3(0.0);

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
void fragment() {
	float t = shimmer_time * shimmer_amount;
	if (stream) {
		// Shallow flowing water: ripple normals advected downstream (so sun and sky highlights
		// depend on view, light and ripples), dark clear body that lets the bed show at steep
		// view angles and reflects at grazing ones, foam only where the reach steps down.
		float across = abs(UV.x - 0.5) * 2.0;
		vec2 q = vec2(UV.x * 3.0, UV.y * 5.0 - t * 0.7);
		float e = 0.04;
		float c0 = fbm(q);
		vec2 grad = vec2(fbm(q + vec2(e, 0.0)) - c0, fbm(q + vec2(0.0, e)) - c0) / e;
		NORMAL_MAP = normalize(vec3(-grad * mix(0.08, 0.2, COLOR.r), 1.0)) * 0.5 + 0.5;
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		// White water: broad foam where the reach steps down, plus thin foam lines along the banks.
		// Riffles everywhere (a mountain stream is broken water), white water where the reach steps down.
		float foam = smoothstep(0.42, 0.72, fbm(vec2(UV.x * 6.0, UV.y * 9.0 - t * 1.1))) * mix(0.4, 1.0, COLOR.r);
		foam = max(foam, smoothstep(0.55, 0.8, across) * smoothstep(0.4, 0.7, fbm(vec2(UV.x * 11.0, UV.y * 4.0 - t * 0.5))) * 0.8);
		ALBEDO = mix(vec3(0.03, 0.09, 0.10), vec3(0.85, 0.9, 0.92), foam);
		float sheen_k = (0.75 + 0.25 * c0) * (1.0 - foam * 0.6);
		EMISSION = day_sheen * sheen_k;
		float sheen_alpha = clamp(dot(day_sheen, vec3(0.333)) * 1.5, 0.0, 0.45);
		ALPHA = clamp(mix(0.45, 0.92, fres) + foam * 0.5 + sheen_alpha, 0.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, across)) * (1.0 - smoothstep(0.1, 0.9, COLOR.g));
		ROUGHNESS = mix(0.06, 0.5, foam);
		SPECULAR = 0.5;
	} else if (mist) {
		vec2 c = (UV - vec2(0.5, 0.55)) * vec2(2.0, 2.4);
		float puff = fbm(UV * 3.0 + vec2(t * 0.02, -t * 0.04));
		ALBEDO = vec3(0.92, 0.94, 0.96);
		ALPHA = (1.0 - smoothstep(0.2, 1.0, length(c))) * (0.5 + 0.5 * puff) * 0.3;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		float across = abs(UV.x - 0.5) * 2.0;
		float flow = fbm(vec2(UV.x * 9.0, UV.y * 14.0 - t * 0.9));
		float fine = fbm(vec2(UV.x * 26.0 + 3.1, UV.y * 40.0 - t * 1.6));
		float streak = smoothstep(0.35, 0.8, flow * 0.65 + fine * 0.45);
		float edge = 1.0 - smoothstep(0.55 - 0.25 * UV.y, 1.0, across);
		ALBEDO = mix(vec3(0.70, 0.80, 0.84), vec3(0.97, 0.98, 0.99), streak);
		// Falling water is translucent and catches the sky from every side: a little self-light by day
		// so the fall stays white when the low sun is behind it (shore fall core fell 75 -> 50, review 05).
		EMISSION = ALBEDO * 0.28 * (1.0 - night) * (1.0 - 0.5 * rain);
		ALPHA = clamp(mix(0.5, 0.95, streak) * edge * smoothstep(0.0, 0.03, UV.y), 0.0, 1.0);
		ROUGHNESS = 0.35;
		SPECULAR = 0.4;
	}
}
