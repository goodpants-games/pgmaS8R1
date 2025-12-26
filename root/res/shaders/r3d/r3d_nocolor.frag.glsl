uniform sampler2D MainTex;

varying mediump vec3 v_normal;
varying vec3 v_view_pos;

vec4 r3d_frag(vec4 color, vec4 tex_color, Image tex, vec2 texture_coords,
              vec3 light_influence);

void effect()
{
    vec4 tex_color = Texel(MainTex, VaryingTexCoord.st);
#ifdef R3D_ALPHA_DISCARD
    if (tex_color.a < 0.5) discard;
#endif

    vec3 light_influence = vec3(1.0, 1.0, 1.0);
    r3d_frag(VaryingColor, tex_color, MainTex, VaryingTexCoord.st, light_influence);
}