vec4 r3d_frag(vec4 color, vec4 tex_color, Image tex, vec2 texture_coords,
              vec2 screen_coords, vec3 light_influence)
{
    vec3 final_rgb = tex_color.rgb * tex_color.a * light_influence;
    return vec4(final_rgb, 1.0) * color;
}