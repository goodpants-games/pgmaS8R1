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

---@param path string
---@return love.Mesh
function mesh.load_obj(path)
    local line_split = {}

    local tclear = table.clear
    local tinsert = table.insert

    ---@type number[]
    local obj_vertices = {}

    ---@type number[]
    local obj_normals = {}

    ---@type (number|boolean)[]
    local faces = {}

    -- ---@type number[]
    -- local obj_uvs = {}

    for line in love.filesystem.lines(path) do
        if line:match("^%s*#") then
            goto continue
        end
        
        ---@cast line string
        tclear(line_split)
        for v in line:gmatch("[^%s]+") do
            tinsert(line_split, v)
        end

        if line_split[1] == "v" then
            assert(#line_split == 4, "vertex definition must contain three components")
            local x = assert(tonumber(line_split[2]), "expected number")
            local y = assert(tonumber(line_split[3]), "expected number")
            local z = assert(tonumber(line_split[4]), "expected number")

            tinsert(obj_vertices, x)
            tinsert(obj_vertices, y)
            tinsert(obj_vertices, z)
        
        elseif line_split[1] == "vn" then
            assert(#line_split == 4, "normal definition must contain three components")
            local x = assert(tonumber(line_split[2]), "expected number")
            local y = assert(tonumber(line_split[3]), "expected number")
            local z = assert(tonumber(line_split[4]), "expected number")

            tinsert(obj_normals, x)
            tinsert(obj_normals, y)
            tinsert(obj_normals, z)
        
        elseif line_split[1] == "f" then
            assert(#line_split == 4, "face definition must contain three vertices")
            table.remove(line_split, 1)

            for i=1, 3 do
                for _, attr in ipairs(string.split(line_split[i], "/")) do
                    if string.len(attr) > 0 then
                        local num = assert(tonumber(attr), "expected number")
                        tinsert(faces, num)
                    else
                        tinsert(faces, false)
                    end
                end
            end
        
        else
            print(("warn: unknown obj def type %s"):format(line_split[1]))
        end
        ::continue::
    end

    ---@type number[][]
    local mesh_data = {}

    assert(#faces % 3 == 0)
    assert(#obj_vertices % 3 == 0)
    assert(#obj_normals % 3 == 0)

    for i=1, #faces, 3 do
        local vtxi = (faces[i+0] - 1) * 3 + 1
        local nrmi = (faces[i+2] - 1) * 3 + 1
        tinsert(mesh_data, {
            obj_vertices[vtxi+0], obj_vertices[vtxi+2], obj_vertices[vtxi+1],
            0, 0,
            obj_normals[nrmi+0], obj_normals[nrmi+2], obj_normals[nrmi+1],
            1, 1, 1, 1
        })
    end

    return mesh.new(mesh_data, "triangles", "dynamic")
end

return mesh