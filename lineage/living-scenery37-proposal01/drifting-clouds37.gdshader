shader_type sky;
#include "res://assets/environment/shared_environment.gdshaderinc"
uniform vec4 top_color : source_color = vec4(.4,.6,.8,1.0);
uniform vec4 horizon_color : source_color = vec4(.8,.85,.85,1.0);
uniform vec4 ground_color : source_color = vec4(.3,.4,.3,1.0);
uniform float night_amount = 0.0;
uniform float rain_amount = 0.0;
uniform vec3 cloud_offset = vec3(0.0);
// Golden-hour glow (all 0 = previous look; only the scenery prototype sets these): the sky turns
// gold toward a glow direction, clouds near it take its colour, and thin cloud margins catch it.
uniform vec3 cloud_glow_dir = vec3(0.0, 0.2, -1.0);
uniform vec4 cloud_glow_color : source_color = vec4(1.0, 0.72, 0.45, 1.0);
uniform float cloud_glow = 0.0;
uniform float cloud_glow_power = 3.0;
uniform float horizon_glow = 0.0;
uniform float horizon_glow_power = 6.0;
// Keeps the glow to a band above the horizon (0 = angular falloff only): the glow lit the whole
// upper frame (vista zenith 69 -> 77, review 07).
uniform float glow_band = 0.0;
float hash3(vec3 p) {
 p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z);
}
float noise3(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void sky() {
 // Direction-based sky, not reference imagery or camera-facing scenery.
 // Proposed explicit cloud drift; no shader TIME or POSITION clock.
 float height=max(EYEDIR.y,0.0);
 vec3 base=mix(horizon_color.rgb,top_color.rgb,pow(height,.45));
 float glow_facing=max(dot(EYEDIR,normalize(cloud_glow_dir)),0.0);
 float band=exp(-max(EYEDIR.y-max(cloud_glow_dir.y,0.0),0.0)*glow_band);
 if(horizon_glow>0.0) base=mix(base,cloud_glow_color.rgb,clamp(pow(glow_facing,horizon_glow_power)*band*horizon_glow,0.0,1.0));
 if(EYEDIR.y<0.0) {
  COLOR=mix(horizon_color.rgb,ground_color.rgb,clamp(-EYEDIR.y*2.0,0.0,1.0));
 } else {
  vec3 p=EYEDIR*7.0+vec3(1.7,2.8,-3.6)+(env_enabled ? env_cloud_offset : cloud_offset);
  float cloud=noise3(p)*.58+noise3(p*2.1)*.28+noise3(p*4.3)*.14;
  float coverage=smoothstep(.52-rain_amount*.08,.70,cloud);
  coverage*=smoothstep(.03,.17,height)*(1.0-night_amount*.92);
  vec3 cloud_color=mix(vec3(.93,.90,.82),vec3(.35,.42,.48),rain_amount*.72);
  cloud_color=mix(cloud_color,vec3(.013,.025,.075),night_amount);
  float glow_k=0.0;
  if(cloud_glow>0.0) {
   glow_k=pow(glow_facing,cloud_glow_power)*band*cloud_glow;
   cloud_color=mix(cloud_color,cloud_glow_color.rgb,clamp(glow_k*0.7,0.0,1.0));
  }
  // Clouds near the glow are denser (glow_k = 0 keeps the previous blend).
  COLOR=mix(base,cloud_color,coverage*mix(mix(.45,.72,rain_amount),.85,clamp(glow_k,0.0,1.0)));
  // Thin cloud margins catch the glow (a gold rim rather than a uniform tint).
  if(cloud_glow>0.0) COLOR+=cloud_glow_color.rgb*glow_k*4.0*coverage*(1.0-coverage)*0.45;
 }
}
