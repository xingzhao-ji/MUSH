// Thin shared parameters; defaults leave inherited materials unchanged.
uniform bool env_enabled = false;
uniform float env_time = 0.0;
uniform float env_detail_time = 0.0;
uniform vec3 env_wind_direction = vec3(.924,0.0,.382);
uniform float env_wind_strength = 0.0;
uniform vec3 env_cloud_offset = vec3(0.0);
uniform float env_cloud_shadow = 0.0;
uniform float env_wetness = 0.0;
uniform vec3 env_player_position = vec3(0.0);
uniform float env_player_bend = 0.0;
uniform float env_motion_scale = 1.0;
uniform bool env_room_enabled = false;
uniform float env_ripple_strength = 0.0;

bool env_sheltered(vec3 p) {
 vec2 a=p.xz; vec2 b=p.xz-vec2(-4.10,-.40); vec2 c=p.xz-vec2(4.95,.60);
 return (dot(a,a)<28.95 && p.y<6.75) || (dot(b,b)<6.35 && p.y<3.42)
  || (env_room_enabled && dot(c,c)<4.71 && p.y<3.40);
}
float env_dapple(vec3 p) {
 // Cheap drifting stylized cloud shadow. No texture/depth/compute pass.
 vec2 q=p.xz*.075-env_cloud_offset.xz*3.0;
 float field=.5+.24*sin(q.x+q.y*.63)+.17*sin(q.y*1.731-q.x*.41)+.09*sin(q.x*2.417+q.y*1.173);
 return env_enabled && !env_sheltered(p) ? smoothstep(.50,.82,field)*env_cloud_shadow : 0.0;
}
float env_surface_wetness(vec3 p) {
 return env_enabled && !env_sheltered(p) ? env_wetness : 0.0;
}
vec3 env_root_shift(vec3 root,float phase) {
 float wave=.68*sin(env_time*.79+phase)+.32*sin(env_time*1.31+phase*.73);
 vec3 relative=root-env_player_position; relative.y=0.0;
 float distance=length(relative);
 float proximity=(1.0-smoothstep(.10,1.10,distance))*(1.0-smoothstep(.8,1.5,abs(root.y-env_player_position.y)));
 vec3 away=relative/max(distance,.001);
 vec3 shift=env_wind_direction*wave*env_wind_strength+away*env_player_bend*proximity;
 // Shared gust plus player response stays inside the original total bound.
 return shift/max(1.0,length(shift));
}
