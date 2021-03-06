local Dir = require("dir")

local Pos = {}

function Pos.add(pos, offset)
  return {x = pos.x+offset.x, y = pos.y+offset.y}
end

function Pos.sub(pos, offset)
  return {x = pos.x-offset.x, y = pos.y-offset.y}
end

function Pos.mul(pos, scale)
  return {x = pos.x*scale, y = pos.y*scale}
end

function Pos.proj(pos, dir)
  return Dir.abs[dir] == Dir.E and math.abs(pos.x) or math.abs(pos.y)
end

function Pos.eq(a, b)
  return a.x == b.x and a.y == b.y
end

function Pos.str(pos)
  return string.format("(%d, %d)", pos.x, pos.y)
end

return Pos