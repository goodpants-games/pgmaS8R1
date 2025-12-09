#ifndef _r3d_lighting_
#define _r3d_lighting_

uniform vec3 u_light_ambient_color;
uniform vec3 u_light_sun_color;
uniform vec3 u_light_sun_direction;

uniform vec3 u_light_spot_pos      [SPOT_LIGHT_COUNT];
uniform vec4 u_light_spot_dir_angle[SPOT_LIGHT_COUNT]; // .xyz = dir, .w = cos(angle)
uniform vec4 u_light_spot_color_pow[SPOT_LIGHT_COUNT]; // .rgb = color, .a = power
uniform vec4 u_light_spot_control  [SPOT_LIGHT_COUNT]; // .x = constant .y = linear, .z = quadratic

uniform vec3 u_light_point_pos      [POINT_LIGHT_COUNT];
uniform vec4 u_light_point_color_pow[POINT_LIGHT_COUNT]; // .rgb - color, .a = power
uniform vec4 u_light_point_control  [POINT_LIGHT_COUNT]; // .x = constant, .y = lienar, .z = quadratic

float r3d_calc_light_influence(vec3 light_pos, float light_power,
                               vec4 light_params, vec3 normal, vec3 view_pos,
                               out vec3 dir)
{
    float constant = light_params.x;
    float linear   = light_params.y;
    float quad     = light_params.z;

    vec3 pos_diff = view_pos - light_pos;
    dir = normalize(pos_diff);

    float facing;
    #ifdef R3D_LIGHT_IGNORE_NORMAL
    facing = 1.0;
    #else
    facing = max(0.0, dot(normal, -dir));
    #endif

    float dist = length(pos_diff);
    float attenuation = 1.0 / (constant + linear * dist + quad * dist * dist);
    float combined_power = attenuation * facing;

    return light_power * combined_power;
}

float r3d_log_snap(float v, float snap)
{
    v = log(v);
    v = floor(v * snap + 0.5) / snap;
    v = exp(v);
    return v;
}

vec3 r3d_calc_lighting(vec3 normal, vec3 view_pos)
{
    vec3 light_sum = vec3(0.0, 0.0, 0.0);
    light_sum += u_light_ambient_color;
    light_sum += u_light_sun_color * max(0.0, dot(normal, -normalize(u_light_sun_direction)));

    vec3 light_source_sum = vec3(0.0, 0.0, 0.0);

    for (int i = 0; i < POINT_LIGHT_COUNT; ++i)
    {
        vec3  light_pos       = u_light_point_pos[i].xyz;
        vec3  light_color     = u_light_point_color_pow[i].rgb;
        float light_power     = u_light_point_color_pow[i].a;
        vec4  light_params    = u_light_point_control[i];

        vec3 dir;
        float light_influence =
            r3d_calc_light_influence(light_pos, light_power, light_params,
                                     normal, view_pos, dir);

        light_source_sum += light_color * light_influence;
    }

    for (int i = 0; i < SPOT_LIGHT_COUNT; ++i)
    {
        vec3  light_pos       = u_light_spot_pos[i].xyz;
        vec3  light_dir       = u_light_spot_dir_angle[i].xyz;
        float light_angle_cos = u_light_spot_dir_angle[i].w;
        vec3  light_color     = u_light_spot_color_pow[i].rgb;
        float light_power     = u_light_spot_color_pow[i].a;
        vec4  light_params    = u_light_spot_control[i];

        vec3 dir;
        float light_influence =
            r3d_calc_light_influence(light_pos, light_power, light_params,
                                     normal, view_pos, dir);

        float cone_visibility = dot(dir, light_dir) - light_angle_cos;
        float vis_influence = (sign(cone_visibility) + 1.0) / 2.0;

        float combined_power = light_influence * vis_influence;
        light_source_sum += light_color * combined_power;
    }

    light_sum.r += r3d_log_snap(light_source_sum.r, 3.0);
    light_sum.g += r3d_log_snap(light_source_sum.g, 3.0);
    light_sum.b += r3d_log_snap(light_source_sum.b, 3.0);

    return light_sum;
}

#endif