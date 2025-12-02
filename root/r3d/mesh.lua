local mesh = {}

mesh.mesh_format = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"a_normal", "float", 3},
    {"VertexColor", "float", 4}
}

---@overload fun(vertices:number[][], mode:love.MeshDrawMode, usage:love.SpriteBatchUsage):love.Mesh
---@overload fun(vertexcount:integer, mode:love.MeshDrawMode, usage:love.SpriteBatchUsage):love.Mesh
function mesh.new(...)
    return Lg.newMesh(mesh.mesh_format, ...)
end

return mesh