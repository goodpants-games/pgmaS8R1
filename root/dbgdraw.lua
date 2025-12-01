---@class DebugDraw
---@field private _draw_list function[]
---@overload fun():DebugDraw
local DebugDraw = batteries.class({ name = "DebugDraw" })

function DebugDraw:new()
    self.enabled = true
    self._draw_list = {}
end

function DebugDraw:color(r, g, b, a)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.setColor(r, g, b, a)
    end)
end

function DebugDraw:push()
    if not self.enabled then return end
    table.insert(self._draw_list, Lg.push)
end

function DebugDraw:pop()
    if not self.enabled then return end
    table.insert(self._draw_list, Lg.pop)
end

function DebugDraw:translate(x, y)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.translate(x, y)
    end)
end

function DebugDraw:point(x, y)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.points(x + 0.5, y + 0.5)
    end)
end

function DebugDraw:rect_lines(x, y, w, h)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.rectangle("line", x + 0.5, y + 0.5, w, h)
    end)
end

function DebugDraw:line(x0, y0, x1, y1)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.line(x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5)
    end)
end

function DebugDraw:flush()
    Lg.push()
    Lg.origin()
    Lg.setColor(1, 1, 1)
    for _, v in ipairs(self._draw_list) do
        v()
    end
    table.clear(self._draw_list)
    Lg.pop()
end

Debug.draw = DebugDraw()

return DebugDraw