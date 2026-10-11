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
 // UV.y increases toward the basin; both negative (env_enabled ? env_detail_time : TIME) terms descend.
 float flow=flow_noise(vec2(UV.x*17.0+world_pos.x*0.7,UV.y*26.0-(env_enabled ? env_detail_time : TIME)*3.1));
 float fine=flow_noise(vec2(UV.x*41.0,UV.y*57.0-(env_enabled ? env_detail_time : TIME)*5.2));
 float streak=flow_noise(vec2(UV.x*29.0,UV.y*4.0-(env_enabled ? env_detail_time : TIME)*0.8));
 float impact=clamp(COLOR.r,0.0,1.0);
 float foam=clamp(smoothstep(0.38,0.83,flow)*0.57+smoothstep(0.59,0.90,fine)*0.23+impact*0.40,0.0,1.0);
 float edge=smoothstep(0.0,0.08,UV.x)*(1.0-smoothstep(0.92,1.0,UV.x));
 ALBEDO=mix(vec3(0.10,0.235,0.27),vec3(0.74,0.80,0.78),0.34+foam*0.64);
 ROUGHNESS=mix(0.17,0.42,foam);
 METALLIC=0.0;
 SPECULAR=0.48;
 ALPHA=edge*clamp(0.68+foam*0.20+streak*0.06+impact*0.06,0.0,0.95);
 EMISSION=vec3(0.006,0.018,0.028)*night_amount;
}
