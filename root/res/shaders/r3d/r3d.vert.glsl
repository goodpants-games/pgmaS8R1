attribute vec3 a_normal;

uniform mat4 u_mat_projection;
uniform mat4 u_mat_modelview;
uniform mat3 u_mat_modelview_norm;

varying mediump vec3 v_normal;
varying vec3 v_view_pos;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    v_normal = normalize(u_mat_modelview_norm * a_normal);

    vec4 view_pos = u_mat_modelview * vec4(vertex_position.xyz, 1.0);
    v_view_pos = view_pos.xyz;
    return u_mat_projection * view_pos;
}