shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform bool room_enabled = false;
uniform vec2 rain_extent = vec2(10.0,8.0);
uint hash_seed(uint s){ s^=s>>uint(16); s*=uint(0x7feb352d); s^=s>>uint(15); s*=uint(0x846ca68b); s^=s>>uint(16); return s; }
float random_value(uint s){ return float(hash_seed(s)%uint(65536))/65535.0; }
bool sheltered(vec3 p){
 vec2 main_delta=p.xz;
 vec2 annex_delta=p.xz-vec2(-4.10,-0.40);
 vec2 room_delta=p.xz-vec2(4.95,0.60);
 return (dot(main_delta,main_delta)<28.95 && p.y<6.75)
     || (dot(annex_delta,annex_delta)<6.35 && p.y<3.42)
     || (room_enabled && dot(room_delta,room_delta)<4.71 && p.y<3.40);
}
void start(){
 uint seed=NUMBER+RANDOM_SEED;
 vec2 offset=(vec2(random_value(seed),random_value(seed+uint(781)))-0.5)*rain_extent*2.0;
 TRANSFORM[3].xyz=(EMISSION_TRANSFORM*vec4(offset.x,0.0,offset.y,1.0)).xyz;
 VELOCITY=env_enabled ? vec3(env_wind_direction.x*env_wind_strength*1.6,-14.0,env_wind_direction.z*env_wind_strength*1.6) : vec3(-0.30,-14.0,0.15);
 COLOR=vec4(1.0);
 ACTIVE=!sheltered(TRANSFORM[3].xyz);
}
void process(){
 if(env_enabled) { VELOCITY.xz=env_wind_direction.xz*env_wind_strength*1.6; }
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 if(sheltered(TRANSFORM[3].xyz)||TRANSFORM[3].y< -1.0){ ACTIVE=false; }
}
