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
// Third gradient stop above the glow band (alpha 0 = two-stop gradient, the previous look): the
// amber-to-blue mix left the vista zenith rose (review 17: rows y0-40 hue 337-350, target 260-320), so
// the sky is pushed to this colour between zenith_lo and zenith_hi (EYEDIR.y).
uniform vec4 zenith_color : source_color = vec4(0.36, 0.3, 0.62, 0.0);
uniform float zenith_lo = 0.38;
uniform float zenith_hi = 0.56;
// How far clouds near the glow take its colour, and the gain of the bright cloud-margin rim
// (0.7 / 0.45 = previous look; the margins whitened the glow band, review 17: saturation 0.27-0.33).
uniform float cloud_glow_tint = 0.7;
uniform float cloud_rim = 0.45;
// Azimuth-dependent top (alpha 0 = previous look): toward the glow's azimuth the gradient tops out in
// this warm colour instead of top_color, and the zenith stop is held back there, so the sky stays amber
// to the zenith on the glow side and turns violet away from it (review 18: the violet zenith took the
// vista further from the goal frame, whose sky is amber to the top).
uniform vec4 warm_top : source_color = vec4(0.79, 0.56, 0.46, 0.0);
uniform float warm_power = 2.0;
// Warm cream cloud bodies by day (alpha 0 = previous neutral clouds).
uniform vec4 cloud_warm : source_color = vec4(1.0, 0.87, 0.68, 0.0);
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
 float warm_k=0.0;
 if(warm_top.a>0.0) warm_k=pow(max(dot(normalize(EYEDIR.xz+vec2(1e-5)),normalize(cloud_glow_dir.xz+vec2(1e-5))),0.0),warm_power)*warm_top.a;
 vec3 base=mix(horizon_color.rgb,mix(top_color.rgb,warm_top.rgb,warm_k),pow(height,.45));
 float glow_facing=max(dot(EYEDIR,normalize(cloud_glow_dir)),0.0);
 float band=exp(-max(EYEDIR.y-max(cloud_glow_dir.y,0.0),0.0)*glow_band);
 if(horizon_glow>0.0) base=mix(base,cloud_glow_color.rgb,clamp(pow(glow_facing,horizon_glow_power)*band*horizon_glow,0.0,1.0));
 if(zenith_color.a>0.0) base=mix(base,zenith_color.rgb,zenith_color.a*smoothstep(zenith_lo,zenith_hi,height)*(1.0-warm_k));
 if(EYEDIR.y<0.0) {
  COLOR=mix(horizon_color.rgb,ground_color.rgb,clamp(-EYEDIR.y*2.0,0.0,1.0));
 } else {
  vec3 p=EYEDIR*7.0+vec3(1.7,2.8,-3.6)+(env_enabled ? env_cloud_offset : cloud_offset);
  float cloud=noise3(p)*.58+noise3(p*2.1)*.28+noise3(p*4.3)*.14;
  float coverage=smoothstep(.52-rain_amount*.08,.70,cloud);
  coverage*=smoothstep(.03,.17,height)*(1.0-night_amount*.92);
  vec3 cloud_color=mix(mix(vec3(.93,.90,.82),cloud_warm.rgb,cloud_warm.a),vec3(.35,.42,.48),rain_amount*.72);
  cloud_color=mix(cloud_color,vec3(.013,.025,.075),night_amount);
  float glow_k=0.0;
  if(cloud_glow>0.0) {
   glow_k=pow(glow_facing,cloud_glow_power)*band*cloud_glow;
   cloud_color=mix(cloud_color,cloud_glow_color.rgb,clamp(glow_k*cloud_glow_tint,0.0,1.0));
  }
  // Clouds near the glow are denser (glow_k = 0 keeps the previous blend).
  COLOR=mix(base,cloud_color,coverage*mix(mix(.45,.72,rain_amount),.85,clamp(glow_k,0.0,1.0)));
  // Thin cloud margins catch the glow (a gold rim rather than a uniform tint).
  if(cloud_glow>0.0) COLOR+=cloud_glow_color.rgb*glow_k*4.0*coverage*(1.0-coverage)*cloud_rim;
 }
}
