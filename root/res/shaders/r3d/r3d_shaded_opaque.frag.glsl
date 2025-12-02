#include "r3d_lighting.glsl"
#include "r3d_frag.glsl"

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec3 light_sum = r3d_calc_lighting(v_normal, v_view_pos);

    vec4 texturecolor = Texel(tex, texture_coords);
    texturecolor.rgb *= light_sum * texturecolor.a;
    return texturecolor * color;
}