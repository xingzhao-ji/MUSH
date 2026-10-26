shader_type spatial;
render_mode cull_disabled;
// Prototype-only copy of lineage/living-scenery37-proposal01/canopy-wind37.gdshader
// (wind, normals and night palette identical). Used only by the prototype's duplicate
// near-tree leaf materials: backlight transmission and specular glare are exposed so
// low backlit sun does not bleach leaves cream. The original shader is unchanged.
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
uniform float backlight_scale = 1.0;
uniform float leaf_specular = 0.5;
// Near-crown LOD crossfade (prototype copied trees only; role 0 = off, exact previous output).
// Each tree's camera distance gives the dense-crown share across [lod_fade_start, lod_fade_end];
// role 1 (dense near crown) keeps pixels whose screen dither is below that share, role 2 (ring
// far crown of the same tree) keeps the rest, so the two LODs dissolve into each other instead
// of swapping at one distance.
uniform float lod_fade_start = 0.0;
uniform float lod_fade_end = 0.0;
uniform float lod_fade_role = 0.0;
varying flat float v_lod_keep;
// Foreground leaf craft (prototype near-crown materials only; 0 = exact previous output): the
// blade polygon's outline is trimmed to a smooth pointed leaf lying inside it, and the blade
// gets a lighter midrib, faint lateral veins and a darker base and lighter thin margin.
uniform float leaf_craft = 0.0;
// Back faces: with cull_disabled the engine already flips NORMAL for back faces before this
// code runs (DO_SIDE_CHECK), so the source shader's own second flip turned every back face's
// normal away from the viewer. Diagnostic only: legacy_side_flip re-applies it (previous
// output); debug_facing shows magenta where the shading normal faces away from the viewer.
uniform bool legacy_side_flip = false;
uniform bool debug_facing = false;
// Relative half-width of the source blade polygon (world.gd _append_ground_leaf): stations at
// 0, .22, .5, .78 and 1 with half-width pow(sin(t*pi), .7), joined by straight chords.
float leaf_chord(float v) {
 float a=min(v,1.0-v);
 return a<.22 ? .7295*a/.22 : mix(.7295,1.0,(a-.22)/.28);
}
varying vec3 world_pos;
void vertex() {
 // Only four canopy resource families are assigned this material. The root at
 // local0 is fixed; world displacement length never exceeds the uniform bound.
 vec3 root=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 v_lod_keep=1.0;
 if(lod_fade_end>lod_fade_start) { v_lod_keep=1.0-smoothstep(lod_fade_start,lod_fade_end,distance(root,INV_VIEW_MATRIX[3].xyz)); }
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
 if(lod_fade_role>.5) {
  float dither=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
  if((lod_fade_role<1.5)==(dither>=v_lod_keep)) { discard; }
 }
 float blade=1.0;
 if(leaf_craft>.5) {
  float v=clamp(UV.y,0.0,1.0);
  float f=abs(UV.x-.5)*2.0;
  if(f*leaf_chord(v)>.919*pow(sin(3.14159265*pow(v,.9)),1.2)) { discard; }
  float rib=(1.0-smoothstep(0.0,.06+fwidth(f),f))*(1.0-smoothstep(.7,1.0,v));
  float vp=v*7.0-f*2.4;
  float vein=smoothstep(.8,1.0,.5+.5*cos(vp*6.2831853))*(1.0-smoothstep(.2,.45,fwidth(vp)))*(1.0-f)*smoothstep(.05,.2,v);
  blade=mix(.84,1.0,smoothstep(0.0,.4,v))*(1.0+.08*smoothstep(.5,1.0,f))*(1.0+.10*rib)*(1.0-.06*vein);
 }
 if(legacy_side_flip && !FRONT_FACING) { NORMAL=-NORMAL; }
 float patch=sin(world_pos.x*2.3+world_pos.z*1.7+world_pos.y*0.2)*0.5+0.5;
 float center=sin(clamp(UV.x,0.0,1.0)*3.14159265)*sin(clamp(UV.y,0.0,1.0)*3.14159265);
 vec3 leaf_color=mix(base_color.rgb,accent_color.rgb,0.08*patch+0.06*center);
 // Proposed art palette follows selected moonlight while day keeps its source greens.
 float luminance=dot(leaf_color,vec3(.2126,.7152,.0722));
 vec3 cool_leaf=night_leaf_palette041.rgb*clamp(luminance/.12,.55,1.55);
 leaf_color=mix(leaf_color,cool_leaf,night_amount*.40);
 ALBEDO=leaf_color*COLOR.rgb*blade;
 ALBEDO*=1.0-env_dapple(world_pos);
 ALBEDO*=mix(1.0,.94,env_surface_wetness(world_pos));
 ROUGHNESS=clamp(roughness_value-0.10*center,0.56,0.94);
 ROUGHNESS=mix(ROUGHNESS,max(.38,ROUGHNESS*.72),env_surface_wetness(world_pos));
 BACKLIGHT=leaf_color*mix(.22,.14,night_amount)*backlight_scale;
 SPECULAR=leaf_specular;
 EMISSION=emission_color.rgb*emission_strength;
 if(debug_facing) {
  ALBEDO=vec3(0.0);
  EMISSION=dot(NORMAL,VIEW)<0.0 ? vec3(1.0,0.0,1.0) : vec3(0.0,1.0,0.0);
 }
}
