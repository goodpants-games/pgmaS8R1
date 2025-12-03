#ifndef _r3d_lighting_
#define _r3d_lighting_

uniform vec3 u_light_ambient_color;
uniform vec3 u_light_sun_color;
uniform vec3 u_light_sun_direction;

uniform vec3 u_light_spot_pos      [SPOTLIGHT_COUNT];
uniform vec4 u_light_spot_dir_angle[SPOTLIGHT_COUNT]; // .xyz = dir, .w = cos(angle)
uniform vec4 u_light_spot_color_pow[SPOTLIGHT_COUNT]; // .rgb = color, .a = power
uniform vec4 u_light_spot_control  [SPOTLIGHT_COUNT]; // .x = constant .y = linear, .z = quadratic

vec3 r3d_calc_lighting(vec3 normal, vec3 view_pos)
{
    vec3 light_sum = vec3(0.0, 0.0, 0.0);
    light_sum += u_light_ambient_color;
    light_sum += u_light_sun_color * max(0.0, dot(normal, -normalize(u_light_sun_direction)));

    for (int i = 0; i < SPOTLIGHT_COUNT; ++i)
    {
        vec3  light_pos   = u_light_spot_pos[i].xyz;
        vec3  light_dir   = u_light_spot_dir_angle[i].xyz;
        float light_angle_cos = u_light_spot_dir_angle[i].w;
        vec3  light_color = u_light_spot_color_pow[i].rgb;
        float light_power = u_light_spot_color_pow[i].a;

        float constant    = u_light_spot_control[i].x;
        float linear      = u_light_spot_control[i].y;
        float quad        = u_light_spot_control[i].z;

        vec3 pos_diff = view_pos - light_pos;
        vec3 dir = normalize(pos_diff);

        float facing;
        #ifdef R3D_LIGHT_IGNORE_NORMAL
        facing = 1.0;
        #else
        facing = max(0.0, dot(normal, -dir));
        #endif

        float cone_visibility = dot(dir, light_dir) - light_angle_cos;
        float vis_influence = (sign(cone_visibility) + 1.0) / 2.0;

        float dist = length(pos_diff);
        float attenuation = 1.0 / (constant + linear * dist + quad * dist * dist);
        float combined_power = attenuation * facing * vis_influence;

        combined_power = log(combined_power);
        combined_power = floor(combined_power * 3.0 + 0.5) / 3.0;
        combined_power = exp(combined_power);

        light_sum += light_color * light_power * combined_power;
    }

    return light_sum;
}

#endif