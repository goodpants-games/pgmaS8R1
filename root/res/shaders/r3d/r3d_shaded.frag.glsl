uniform vec3 u_light_ambient_color;
uniform vec3 u_light_sun_color;
uniform vec3 u_light_sun_direction;

uniform vec3 u_light_spot_pos      [SPOTLIGHT_COUNT];
uniform vec4 u_light_spot_dir_angle[SPOTLIGHT_COUNT]; // .xyz = dir, .w = angle
uniform vec4 u_light_spot_color_pow[SPOTLIGHT_COUNT]; // .rgb = color, .a = power

varying mediump vec3 v_normal;
varying vec3 v_view_pos;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec3 light_sum = vec3(0.0, 0.0, 0.0);
    light_sum += u_light_ambient_color;
    light_sum += u_light_sun_color * max(0.0, dot(v_normal, -normalize(u_light_sun_direction)));

    for (int i = 0; i < SPOTLIGHT_COUNT; ++i)
    {
        vec3 pos = u_light_spot_pos[i].xyz;
        vec3 light_dir = u_light_spot_dir_angle[i].xyz;
        float angle = u_light_spot_dir_angle[i].w;
        vec3 color = u_light_spot_color_pow[i].rgb;
        float power = u_light_spot_color_pow[i].a;

        vec3 pos_diff = v_view_pos - pos;
        vec3 dir = normalize(pos_diff);
        float facing = max(0.0, dot(v_normal, -dir));

        float cone_visibility = dot(dir, light_dir) - cos(angle);
        float vis_influence = (sign(cone_visibility) + 1.0) / 2.0;

        float dist = max(1.0, length(pos_diff) / 60.0);
        light_sum += (color * power / dist) * facing * vis_influence;
    }

    vec4 texturecolor = Texel(tex, texture_coords);
    texturecolor.rgb *= light_sum;
    return texturecolor * color;
}