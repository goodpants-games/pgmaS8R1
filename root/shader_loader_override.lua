print(love.graphics.getRendererInfo())

local gles = love.graphics.getRendererInfo():find("ES") ~= nil
local supports_glsl3 = love.graphics.getSupported().glsl3

---@diagnostic disable-next-line
local orig_transformGLSLErrorMessages = love.graphics._transformGLSLErrorMessages
---@diagnostic disable-next-line
local orig_newShader = love.graphics.newShader

---@param str string
local function str_lines(str)
	local s = 1
	local len = str:len()
	return function()
		if s > len then
			return nil
		end

		local e = str:find("\n", s, true) or len + 1
		local res = str:sub(s, e - 1)
		if res:sub(-1, -1) == "\r" then
			res = res:sub(1, -2)
		end
		s=e+1
		return res
	end
end

local function get_language_target(code)
	if not code then return nil end
	return (code:match("^%s*#pragma language (%w+)")) or "glsl1"
end

local function line_set(is_glsl1, lineno, sourceno)
	if not is_glsl1 or gles then
		lineno = lineno + 1
	end 

	return ("#line %i %i"):format(lineno, sourceno)
end

local function normalize_path(path)
	local stack = {}
	for p in string.gmatch(path, "[^/]+") do
		if p ~= "." then
			if p == ".." and stack[1] then
				table.remove(stack)
			else
				table.insert(stack, p)
			end
		end
	end

	return table.concat(stack, "/")
end

local function process_file(output, src, require_file)
	local src_filename = src
	local is_file = false
	if require_file or love.filesystem.getInfo(src) then
		is_file = true
		src = assert(love.filesystem.read(src))
		src_filename = normalize_path(src_filename)
	end

	local lines = output.lines
	local source_list = output.source_list

	local sourceno = #source_list
	if is_file then
		table.insert(source_list, src_filename)
	else
		table.insert(source_list, "<string>")
	end

	if is_file then
		output.sources[src_filename] = true
	end

	local target_lang = get_language_target(src)
	if not output.target_lang then
		output.target_lang = target_lang	
	end

	if output.target_lang ~= target_lang then
		assert(is_file)
		error(src_filename .. ": mismatched shader language", 0)
	end

	local lang = target_lang or "glsl1"
	local glsl1on3 = false
	if lang == "glsl1" and supports_glsl3 then
		lang = "glsl3"
		glsl1on3 = true
	end
	local is_glsl1 = lang == "glsl1" or glsl1on3

	table.insert(lines, line_set(is_glsl1, 0, sourceno))

	local lineno = 1

	local function fmt_error(errmsg, ...)
		if is_file then
			return ("%s:%i: " .. errmsg):format(src_filename, lineno, ...)
		else
			return ("%i: " .. errmsg):format(lineno, ...)
		end
	end

	for line in str_lines(src) do
		---@type string?
		local include_path = string.match(line, "^%s*#%s*include%s(.*)")
		if include_path then
			local is_relative

			if include_path:sub(1, 1) == "<" then
				if not include_path:sub(-1, -1) == ">" then
					error(fmt_error("expected closing angle bracket"), 0)
				end

				is_relative = false
			elseif include_path:sub(1, 1) == "\"" then
				if not include_path:sub(-1, -1) == "\"" then
					error(fmt_error("expected closing angle bracket"), 0)
				end

				is_relative = true
			else
				error(fmt_error("expected '\"' or '<'"), 0)
			end

			include_path = include_path:sub(2, -2)
			if is_relative and is_file then
				include_path = src_filename .. "/../" .. include_path
			end

			include_path = normalize_path(include_path)

			if output.sources[include_path] then
				error(fmt_error("recursive include"), 0)
			end

			if not love.filesystem.getInfo(include_path) then
				error(fmt_error("%s does not exist", include_path), 0)
			end

			process_file(output, include_path, true)
			table.insert(lines, line_set(is_glsl1, lineno, sourceno))
		else
			table.insert(lines, line)
		end

		lineno=lineno+1
	end
end

local function shader_preproc(src, output)
	if src == nil then
		return nil
	end

	output.lines = {}
	output.source_list = {}
	output.sources = {}

	process_file(output, src, false)

	while string.match(output.lines[#output.lines], "^#line%s") do
		table.remove(output.lines)
	end

	-- for k,v in pairs(output.source_list) do
	-- 	print(k,v)
	-- end

	local result = table.concat(output.lines, "\n")
	return result
end

local function transformGLSLErrorMessages(message, sources)
	local shadertype = message:match("Cannot compile (%a+) shader code")
	local compiling = shadertype ~= nil
	if not shadertype then
		shadertype = message:match("Error validating (%a+) shader")
	end
	if not shadertype then return message end
	local lines = {}
	local prefix = compiling and "Cannot compile " or "Error validating "
	lines[#lines+1] = prefix..shadertype.." shader code:"
	for l in message:gmatch("[^\n]+") do
		-- nvidia: 0(<linenumber>) : error/warning [NUMBER]: <error message>
		local sourceno, linenumber, what, message = l:match("^(%d+)%((%d+)%)%s*:%s*(%w+)[^:]+:%s*(.+)$")
		if not sourceno then
			-- AMD: ERROR 0:<linenumber>: error/warning(#[NUMBER]) [ERRORNAME]: <errormessage>
			sourceno, linenumber, what, message = l:match("^%w+: %(d+):(%d+):%s*(%w+)%([^%)]+%)%s*(.+)$")
		end
		if not sourceno then
			-- macOS (?): ERROR: 0:<linenumber>: <errormessage>
			what, sourceno, linenumber, message = l:match("^(%w+): (%d+):(%d+): (.+)$")
		end
		if not sourceno and l:match("^ERROR:") then
			what = l
		end
		if sourceno and linenumber and what and message then
			local source_name = sources[sourceno + 1]
			if source_name == "<string>" then
				source_name = "Line "
			else
				source_name = source_name .. ":"
			end

			lines[#lines+1] = ("%s%d: %s: %s"):format(source_name, linenumber, what, message)
		elseif what then
			lines[#lines+1] = what
		end
	end
	-- did not match any known error messages
	if #lines == 1 then return message end
	return table.concat(lines, "\n")
end

function love.graphics.newShader(pixelcode, vertexcode)
	local p_out = {}
	local v_out = {}

	local s, err = pcall(orig_newShader, shader_preproc(pixelcode, p_out), shader_preproc(vertexcode, v_out))
	if s then
		return err
	end

	-- print(err)
	local first_line = assert(err:match("^(.*)[\r\n]"))

	if string.find(first_line, "vertex") then
		err = transformGLSLErrorMessages(err, v_out.source_list)
	elseif string.find(first_line, "fragment") or string.find(first_line, "pixel") then
		err = transformGLSLErrorMessages(err, p_out.source_list)
	end

	error(err, 2)
end

function love.graphics._transformGLSLErrorMessages(message)
	return message
end