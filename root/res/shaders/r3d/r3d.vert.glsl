attribute vec3 a_normal;

uniform mat4 u_mat_projection;
uniform mat4 u_mat_modelview;
uniform mat3 u_mat_modelview_norm;

varying mediump vec3 v_normal;
varying vec3 v_view_pos;

#ifdef R3D_SHADING_VERTEX
varying vec3 v_light_influence;
#include "lighting.glsl"
#endif

vec3 r3d_vert(vec3 vertex_position);

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec3 pos = r3d_vert(vertex_position.xyz);
    vec4 view_pos = u_mat_modelview * vec4(pos, 1.0);
    v_view_pos = view_pos.xyz;
    v_normal = normalize(u_mat_modelview_norm * a_normal);

#ifdef R3D_SHADING_VERTEX
    v_light_influence = r3d_calc_lighting(v_normal, v_view_pos);
#endif

    return u_mat_projection * view_pos;
}