shader_type spatial;
render_mode cull_disabled;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform vec4 water_color : source_color = vec4(0.085,0.235,0.225,1.0);
uniform float night_amount = 0.0;
uniform float rain_amount = 0.0;
varying vec3 world_pos;
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world_pos.z*2.8+world_pos.x*1.7+(env_enabled ? env_detail_time : TIME)*1.1)*0.012;
 VERTEX.y+=sin(world_pos.x*6.2-world_pos.z*1.3+(env_enabled ? env_detail_time : TIME)*1.6)*0.008;
}
void fragment() {
 float flow=sin(world_pos.z*5.2-world_pos.x*2.3-(env_enabled ? env_detail_time : TIME)*1.25);
 float cross_flow=sin(world_pos.x*10.8+world_pos.z*1.6+(env_enabled ? env_detail_time : TIME)*0.83);
 float detail=sin(world_pos.z*18.7+sin(world_pos.x*4.8)-(env_enabled ? env_detail_time : TIME)*2.0);
 float shore=smoothstep(0.78,1.0,abs(world_pos.x-9.0)/1.19);
 float broken=0.5+0.5*sin(world_pos.z*13.7+sin(world_pos.x*8.1)-(env_enabled ? env_detail_time : TIME)*1.1);
 float basin=exp(-pow((world_pos.z+19.03)/0.68,2.0))*exp(-pow((world_pos.x-9.0)/0.96,4.0));
 float foam=basin*smoothstep(0.62,0.92,broken)*0.24;
 ALBEDO=mix(water_color.rgb,vec3(0.075,0.14,0.18),night_amount*0.60);
 ALBEDO+=vec3(0.012,0.020,0.016)*(flow*0.24+cross_flow*0.16+0.5);
 ALBEDO=mix(ALBEDO,vec3(0.57,0.65,0.61),foam);
 ROUGHNESS=(night_amount>0.0 ? mix(0.09,0.35,clamp(night_amount,0.0,1.0)) : 0.09)+rain_amount*0.055+shore*0.06+foam*0.20;
 METALLIC=0.0;
 SPECULAR=night_amount>0.0 ? mix(0.55,0.12,clamp(night_amount,0.0,1.0)) : 0.55;
 vec3 normal_world=normalize(vec3(flow*0.025+cross_flow*0.026,1.0,detail*0.017+cross_flow*0.011));
 vec2 ripple_delta=world_pos.xz-env_player_position.xz;
 float ripple_distance=length(ripple_delta);
 float ripple=env_enabled ? cos(ripple_distance*21.0-env_time*5.0)*exp(-ripple_distance*3.0)*env_ripple_strength*.028 : 0.0;
 float rain_impact=env_enabled ? sin(world_pos.x*37.0+world_pos.z*43.0-env_time*7.0)*rain_amount*env_ripple_strength*.008 : 0.0;
 vec2 radial=ripple_delta/max(.001,ripple_distance);
 normal_world.xz+=radial*ripple+vec2(rain_impact,-rain_impact*.7)+env_wind_direction.xz*env_wind_strength*.006;
 NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(normal_world));
 ALBEDO*=1.0-env_dapple(world_pos);
 // Scene SSR/sky remain the reflection source; no painted lantern bands.
 EMISSION=vec3(0.0);
}
