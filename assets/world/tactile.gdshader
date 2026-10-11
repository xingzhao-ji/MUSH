shader_type spatial;
render_mode cull_disabled;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.7,0.5,0.3,1.0);
uniform vec4 accent_color : source_color = vec4(0.5,0.3,0.15,1.0);
uniform float roughness_value = 0.85;
uniform float texture_scale = 4.0;
uniform float grain = 0.14;
uniform float grain_kind = 0.0;
uniform float foliage = 0.0;
uniform float emission_strength = 0.0;
uniform float lamella_emission = 0.0;
uniform float lamella_recess = 0.0;
uniform float lamella_root_fade = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0,0.55,0.14,1.0);
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform float surface_blend = 0.0;
uniform float surface_scale = 1.0;
uniform bool surface_triplanar = false;
uniform float env_anchor_enabled = 0.0;
uniform float env_root_y = 0.0;
varying vec3 local_pos;
varying vec3 view_pos;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 if(env_enabled && env_anchor_enabled>.5) {
  vec3 root=(MODEL_MATRIX*vec4(0.0,env_root_y,0.0,1.0)).xyz;
  vec3 local_shift=inverse(mat3(MODEL_MATRIX))*env_root_shift(root,dot(root.xz,vec2(.173,.117)))*.020;
  // Full native root plane is fixed, including grass bases away from XZ zero.
  float height_from_root=VERTEX.y-env_root_y;
  float r=clamp(height_from_root/1.25,0.0,1.0);
  float weight=r*r*(3.0-2.0*r);
  vec3 grad=height_from_root>0.0 && height_from_root<1.25 ? vec3(0.0,6.0*r*(1.0-r)/1.25,0.0) : vec3(0.0);
  float det=1.0+dot(grad,local_shift);
  NORMAL=normalize(NORMAL-grad*dot(local_shift,NORMAL)/max(det,.1));
  VERTEX+=local_shift*weight;
 }
 local_pos=VERTEX;
 view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
float hash(vec3 p) { p=fract(p*0.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float noise3(vec3 p) { vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z); }
void fragment() {
 if (!FRONT_FACING) { NORMAL = -NORMAL; }
 vec3 p=local_pos*texture_scale;
 float n=noise3(p)*0.5+noise3(p*3.0)*0.27+noise3(p*9.0)*0.12;
 float streak=sin(p.y*2.0+noise3(p*0.42)*12.0)*0.5+0.5;
 if(grain_kind>0.5 && grain_kind<1.5) { streak=sin((p.x+p.z*0.25)*7.0+noise3(vec3(p.x*0.6,p.y*0.05,p.z))*9.0)*0.5+0.5; }
 if(grain_kind>1.5) { streak=sin(UV.x*670.0+noise3(p)*2.7)*0.5+0.5; }
 float v=clamp(n*0.58+streak*0.42,0.0,1.0);
 ALBEDO=mix(base_color.rgb,accent_color.rgb,v*grain)*COLOR.rgb;
 float surface_height=0.0;
 if(surface_blend>0.001) {
  vec3 sample_color;
  if(surface_triplanar) {
   vec3 weights=pow(abs(normalize(world_normal)),vec3(4.0));
   weights/=max(weights.x+weights.y+weights.z,0.0001);
   vec3 tex_pos=world_pos*surface_scale;
   sample_color=texture(surface_albedo,tex_pos.zy).rgb*weights.x
    +texture(surface_albedo,tex_pos.xz).rgb*weights.y
    +texture(surface_albedo,tex_pos.xy).rgb*weights.z;
  } else {
   sample_color=texture(surface_albedo,UV*surface_scale).rgb;
  }
  ALBEDO=mix(ALBEDO,sample_color*COLOR.rgb,surface_blend);
  // Albedo-derived low relief is a proposal, not a generated normal/height map.
  surface_height=dot(sample_color,vec3(0.2126,0.7152,0.0722))*surface_blend*0.012;
 }
 ROUGHNESS=roughness_value+0.06*n;
 float wet=env_surface_wetness(world_pos)*smoothstep(.15,.75,world_normal.y);
 ALBEDO*=mix(1.0,.94,wet)*(1.0-env_dapple(world_pos));
 ROUGHNESS=mix(ROUGHNESS,max(.28,ROUGHNESS*.62),wet);
 // Millimetre-scale relief follows the material grain. The algorithm requires
 // an explicit material rewrite in Unreal.
 float relief=(n*0.45+streak*0.55)*grain*0.015+surface_height;
 vec3 dx=dFdx(view_pos);
 vec3 dy=dFdy(view_pos);
 vec3 rx=cross(dy,NORMAL);
 vec3 ry=cross(NORMAL,dx);
 float determinant=dot(dx,rx);
 vec3 gradient=(rx*dFdx(relief)+ry*dFdy(relief))*sign(determinant)/max(abs(determinant),0.00001);
 NORMAL=normalize(NORMAL-gradient);
 EMISSION=emission_color.rgb*emission_strength;
 if(lamella_emission>0.5) {
  // Lamella UV.x runs from the backing to the exposed fold edge.
  float ridge=0.055+0.945*pow(clamp(UV.x,0.0,1.0),3.0);
  float fold_variation=0.78+0.22*noise3(world_pos*0.65);
  // Proposal05 main-only: UV.y maps hidden neck0 to outerlip1.
  float tissue_gate=mix(1.0,smoothstep(0.0,0.29,UV.y),clamp(lamella_root_fade,0.0,1.0));
  EMISSION*=ridge*fold_variation*tissue_gate;
  // Tunable material proposal: slight diffuse separation between rounded folds.
  // The gradient follows authored fold UVs; it does not add geometry or lights.
  float fold_diffuse=mix(1.0-lamella_recess,1.0,sqrt(clamp(UV.x,0.0,1.0)));
  ALBEDO*=mix(1.0,fold_diffuse,tissue_gate);
 }
 BACKLIGHT=base_color.rgb*foliage*0.18;
}
