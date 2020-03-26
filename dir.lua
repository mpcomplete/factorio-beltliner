-- Direction-related helpers.
local Dir = {}

Dir.N = defines.direction.north
Dir.S = defines.direction.south
Dir.E = defines.direction.east
Dir.W = defines.direction.west

-- Convert a direction to a Position representing a 1 tile offset in that dir.
Dir.toOffset = {
  [Dir.N] = {x= 0, y=-1},
  [Dir.S] = {x= 0, y= 1},
  [Dir.E] = {x= 1, y= 0},
  [Dir.W] = {x=-1, y= 0},
}
-- Convert a direction to an orientation (e.g. a percentage clockwise rotation from north).
Dir.toOrientation = {
  [Dir.N] = 0,
  [Dir.E] = .25,
  [Dir.S] = .50,
  [Dir.W] = .75,
}
-- Convert a direction to the positive X/Y axis: S and E.
Dir.abs = {
  [Dir.N] = Dir.S,
  [Dir.S] = Dir.S,
  [Dir.E] = Dir.E,
  [Dir.W] = Dir.E,
}
-- Single 90 degree clockwise rotation.
Dir.R  = {
  [Dir.N] = Dir.E,
  [Dir.E] = Dir.S,
  [Dir.S] = Dir.W,
  [Dir.W] = Dir.N,
}

function Dir.isParallel(a, b)
  return Dir.abs[a] == Dir.abs[b]
end

-- Returns the primary direction of `to` relative to `from`. If it's directly 45 degrees, prefer N or S.
function Dir.getPrimary(from, to)
  local dx = to.x - from.x
  local dy = to.y - from.y
  if math.abs(dx) > math.abs(dy) then
    return dx > 0 and Dir.E or Dir.W
  else
    return dy > 0 and Dir.S or Dir.N
  end
end

return Dir