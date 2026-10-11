shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://assets/environment/shared_environment.gdshaderinc"

// Explicit provisional firefly motion. The existing mesh, light, emitter count,
// lifetime, box, zero gravity and speed/scale ranges remain unchanged.
uniform vec3 emission_box = vec3(15.0, 0.8, 15.0);
uniform float speed_min = 0.08;
uniform float speed_max = 0.30;
uniform float scale_min = 0.60;
uniform float scale_max = 1.30;

uint hash_seed(uint value) {
	value = (value ^ (value >> 16u)) * 2246822519u;
	value = (value ^ (value >> 13u)) * 3266489917u;
	return value ^ (value >> 16u);
}
float random_value(inout uint seed) {
	seed = hash_seed(seed + 747796405u);
	return float(seed & 16777215u) / 16777215.0;
}
void start() {
	uint seed = hash_seed(NUMBER ^ RANDOM_SEED);
	vec3 point = vec3(random_value(seed), random_value(seed), random_value(seed));
	point = (point * 2.0 - 1.0) * emission_box;
	float y = random_value(seed) * 2.0 - 1.0;
	float angle = random_value(seed) * TAU;
	float radius = sqrt(max(0.0, 1.0 - y * y));
	vec3 direction = vec3(cos(angle) * radius, y, sin(angle) * radius);
	float speed = mix(speed_min, speed_max, random_value(seed));
	float size = mix(scale_min, scale_max, random_value(seed));
	TRANSFORM = mat4(1.0);
	TRANSFORM[0].x = size;
	TRANSFORM[1].y = size;
	TRANSFORM[2].z = size;
	TRANSFORM[3].xyz = point;
	VELOCITY = direction * speed;
	TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	VELOCITY = mat3(EMISSION_TRANSFORM) * VELOCITY;
	COLOR = vec4(1.0);
	CUSTOM = vec4(0.0);
}
void process() {
	TRANSFORM[3].xyz += (VELOCITY + (env_enabled ? env_wind_direction*env_wind_strength*.08 : vec3(0.0))) * DELTA;
	CUSTOM.x += DELTA;
	if (CUSTOM.x >= LIFETIME) { ACTIVE = false; }
}
