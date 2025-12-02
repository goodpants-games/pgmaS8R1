uniform vec3 u_light_ambient_color;
uniform vec3 u_light_sun_color;
uniform vec3 u_light_sun_direction;

varying vec3 v_normal;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec3 sun_influence =
        u_light_sun_color * max(0.0, dot(v_normal, -normalize(u_light_sun_direction)));
    vec3 ambient_influence = u_light_ambient_color;

    vec4 texturecolor = Texel(tex, texture_coords);
    texturecolor.rgb *= ambient_influence + sun_influence;
    return texturecolor * color;
}