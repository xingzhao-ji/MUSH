shader_type spatial;
render_mode cull_disabled;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.2,0.4,0.12,1.0);
uniform vec4 accent_color : source_color = vec4(0.4,0.5,0.2,1.0);
uniform float roughness_value = 0.88;
uniform float emission_strength = 0.0;
uniform float night_amount = 0.0;
uniform vec4 night_leaf_palette041 : source_color = vec4(.040,.090,.260,1.0);
uniform vec4 emission_color : source_color = vec4(0.4,0.4,1.0,1.0);
uniform float wind_time = 0.0;
uniform float wind_displacement_m = 0.0;
varying vec3 world_pos;
void vertex() {
 // Only four canopy resource families are assigned this material. The root at
 // local0 is fixed; world displacement length never exceeds the uniform bound.
 vec3 root=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float phase=dot(root.xz,vec2(.173,.117));
 float gust=.68*sin(wind_time*.79+phase)+.32*sin(wind_time*1.31+phase*.73);
 vec3 world_shift=env_enabled ? env_root_shift(root,phase)*wind_displacement_m : normalize(vec3(.92,0.0,.38))*wind_displacement_m*gust;
 vec3 local_shift=inverse(mat3(MODEL_MATRIX))*world_shift;
 float distance_from_root=length(VERTEX);
 float r=clamp(distance_from_root/1.25,0.0,1.0);
 float weight=r*r*(3.0-2.0*r);
 vec3 grad=distance_from_root>.00001 && distance_from_root<1.25 ? (6.0*r*(1.0-r)/1.25)*VERTEX/distance_from_root : vec3(0.0);
 float jacobian_det=1.0+dot(grad,local_shift);
 // Analytic inverse-transpose of J=I+local_shift*transpose(grad).
 NORMAL=normalize(NORMAL-grad*dot(local_shift,NORMAL)/max(jacobian_det,.1));
 VERTEX+=local_shift*weight;
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
 float patch=sin(world_pos.x*2.3+world_pos.z*1.7+world_pos.y*0.2)*0.5+0.5;
 float center=sin(clamp(UV.x,0.0,1.0)*3.14159265)*sin(clamp(UV.y,0.0,1.0)*3.14159265);
 vec3 leaf_color=mix(base_color.rgb,accent_color.rgb,0.08*patch+0.06*center);
 // Proposed art palette follows selected moonlight while day keeps its source greens.
 float luminance=dot(leaf_color,vec3(.2126,.7152,.0722));
 vec3 cool_leaf=night_leaf_palette041.rgb*clamp(luminance/.12,.55,1.55);
 leaf_color=mix(leaf_color,cool_leaf,night_amount*.40);
 ALBEDO=leaf_color*COLOR.rgb;
 ALBEDO*=1.0-env_dapple(world_pos);
 ALBEDO*=mix(1.0,.94,env_surface_wetness(world_pos));
 ROUGHNESS=clamp(roughness_value-0.10*center,0.56,0.94);
 ROUGHNESS=mix(ROUGHNESS,max(.38,ROUGHNESS*.72),env_surface_wetness(world_pos));
 BACKLIGHT=leaf_color*mix(.22,.14,night_amount);
 EMISSION=emission_color.rgb*emission_strength;
}
