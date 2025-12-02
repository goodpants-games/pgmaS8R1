attribute vec3 a_normal;

uniform mat4 u_mat_projection;
uniform mat4 u_mat_modelview;
uniform mat3 u_mat_modelview_norm;

varying vec3 v_normal;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    v_normal = normalize(u_mat_modelview_norm * a_normal);
    return u_mat_projection * u_mat_modelview * vec4(vertex_position.xyz, 1.0);
}