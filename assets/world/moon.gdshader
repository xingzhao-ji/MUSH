shader_type spatial;
render_mode unshaded;
varying vec3 sphere_coord;
void vertex() { sphere_coord=normalize(VERTEX); }
float hash3(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float noise3(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float crater(vec3 p,vec3 center,float radius) {
 float d=length(p-normalize(center))/radius;
 float bowl=1.0-smoothstep(.14,.88,d);
 float lip=exp(-pow((d-.88)/.13,2.0))*.30;
 return bowl-lip;
}
void fragment() {
 vec3 p=normalize(sphere_coord);
 float mare=smoothstep(.42,.70,noise3(p*3.8+vec3(1.4,3.2,.7)));
 float relief=crater(p,vec3(-.32,.10,.94),.34)*.13
  +crater(p,vec3(.25,-.33,.90),.22)*.16
  +crater(p,vec3(-.48,-.51,.71),.16)*.11;
 float fine=noise3(p*22.0)*.035;
 vec3 surface=mix(vec3(.65,.77,.93),vec3(.29,.42,.63),clamp(mare*.58+relief+fine,0.0,.72));
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 surface*=.44+.56*sqrt(facing);
 ALBEDO=surface;
 EMISSION=surface*.20;
}
