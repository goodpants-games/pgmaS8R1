local r3d = {}

---@class r3d.Object
---@field set_position fun(self:r3d.Object, x:number, y:number, z:number)
---@field get_position fun(self:r3d.Object):(number, number, number)

r3d.world = require("r3d.world")
r3d.model = require("r3d.model")
r3d.mesh_format = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"a_normal", "float", 3},
    {"VertexColor", "float", 4}
}

---@overload fun(vertices:number[][], mode:love.MeshDrawMode, usage:love.SpriteBatchUsage):love.Mesh
---@overload fun(vertexcount:integer, mode:love.MeshDrawMode, usage:love.SpriteBatchUsage):love.Mesh
function r3d.createMesh(...)
    return Lg.newMesh(r3d.mesh_format, ...)
end

return r3d