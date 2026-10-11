shader_type spatial;
render_mode cull_disabled;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform float night_amount = 0.0;
varying vec3 world_pos;
float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float flow_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 if(!FRONT_FACING){ NORMAL=-NORMAL; }
 // Authored UV.y increases downward. Negative (env_enabled ? env_detail_time : TIME) moves detail to the basin.
 float flow=flow_noise(vec2(world_pos.x*5.0,UV.y*18.0-(env_enabled ? env_detail_time : TIME)*3.0));
 float fine=flow_noise(vec2(world_pos.x*13.0,UV.y*34.0-(env_enabled ? env_detail_time : TIME)*5.0));
 float foam=smoothstep(0.35,0.85,flow)*0.65+smoothstep(0.65,0.90,fine)*0.20;
 ALBEDO=mix(vec3(0.11,0.24,0.30),vec3(0.70,0.79,0.81),0.20+foam*0.75);
 ROUGHNESS=0.28;
 METALLIC=0.0;
 SPECULAR=0.35;
 EMISSION=vec3(0.006,0.018,0.028)*night_amount;
}
