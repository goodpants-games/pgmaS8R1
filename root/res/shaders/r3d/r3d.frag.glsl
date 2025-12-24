varying mediump vec3 v_normal;
varying vec3 v_view_pos;

#ifdef R3D_SHADING
#   ifdef R3D_SHADING_VERTEX
varying vec3 v_light_influence;
#   else
#include "lighting.glsl"
#   endif
#endif

vec4 r3d_frag(vec4 color, vec4 tex_color, Image tex, vec2 texture_coords,
              vec2 screen_coords, vec3 light_influence);

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 tex_color = Texel(tex, texture_coords);
#ifdef R3D_ALPHA_DISCARD
    if (tex_color.a < 0.5) discard;
#endif

#ifdef R3D_SHADING
#   ifdef R3D_SHADING_VERTEX
    vec3 light_influence = v_light_influence;
#   else
    vec3 light_influence = r3d_calc_lighting(v_normal, v_view_pos);
#   endif
#else
    vec3 light_influence = vec3(1.0, 1.0, 1.0);
#endif

    return r3d_frag(color, tex_color, tex, texture_coords, screen_coords,
                    light_influence);
}