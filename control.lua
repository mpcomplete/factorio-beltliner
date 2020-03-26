local Player = require("player")
local Dir = require("dir")
local Pos = require("pos")

function debug(player, fmt, ...)
  global.debugId = 1 + (global.debugId or 0)
  player.print(string.format("%d:"..fmt, global.debugId, ...))
end
-- debug = function() end

function onInit()
  global = global or {}
end
script.on_configuration_changed(onInit)
script.on_init(onInit)

-- Finds an entity at the given position with the given protoName, or a ghost with that ghost_prototype.
function findEntity(player, protoName, pos)
  local e = player.surface.find_entity(protoName, pos)
  if not e then
    local ghost = player.surface.find_entity("entity-ghost", pos)
    if ghost and ghost.ghost_prototype.name == protoName then e = ghost end
  end
  return e
end

-- Find number of parallel lanes that are immediately adjacent to and facing in the same direction as the given entity.
function findParallelLanes(player, beltProto, entity)
  local pos = entity.bounding_box.left_top
  local result = {leftTop = pos, count = 1, dir = entity.direction}
  local offset = Dir.toOffset[Dir.R[entity.direction]]

  for neg=0,1 do
    local sign = neg == 0 and -1 or 1
    for i=1,100 do
      local newPos = Pos.add(pos, Pos.mul(offset, sign*i))
      local e = findEntity(player, beltProto.name, newPos)
      if e and e.direction == entity.direction then
        if newPos.x < result.leftTop.x or newPos.y < result.leftTop.y then
          result.leftTop = newPos
        end
        result.count = result.count+1
      else
        break
      end
    end
  end

  return result
end

-- Plan the start position for each lane of belts, potentially handling a corner.
function planLanes(player, leftTop, numLanes, startDir, targetDir)
  local lanes = {}

  if Dir.isParallel(startDir, targetDir) then
    local perpendicularOffset = Dir.toOffset[Dir.abs[Dir.R[targetDir]]] -- N/S to E, E/W to S.
    local curPos = leftTop
    for i=1,numLanes do
      lanes[i] = {pos = curPos}
      curPos = Pos.add(curPos, perpendicularOffset)
    end
  else
    -- If we're heading east or south, then the top left is the furthest belt. Otherwise, the bottom left is.
    local curPos = (targetDir == Dir.E or targetDir == Dir.S) and
      leftTop or
      Pos.add(leftTop, Pos.mul(Dir.toOffset[targetDir], -(numLanes-1)))

    for i=1,numLanes do
      lanes[i] = {pos = curPos, cornerLength = numLanes - i + 1}
      curPos = Pos.add(curPos, Dir.toOffset[targetDir])
      curPos = Pos.sub(curPos, Dir.toOffset[startDir])
    end
  end

  return lanes
end

-- Place belts in a straight line from curPos to destPos, using undergrounds to jump over obstacles.
-- TODO: configure undergrounding strategy.
function planBelts(player, beltProto, lanes, dir, destPos)
  local perpendicularOffset = Dir.toOffset[Dir.abs[Dir.R[dir]]] -- N/S to E, E/W to S.
  local undergroundProto = getUndergroundForBelt(beltProto)
  local belts = {}
  local lastPos = nil

  for laneIdx,lane in pairs(lanes) do
    local length = Pos.proj(Pos.sub(destPos, lane.pos), dir)
    local beltPosAt = function(i) return Pos.add(lane.pos, Pos.mul(Dir.toOffset[dir], i-1)) end
    local i=1
    if not lastPos then
      lastPos = Pos.add(lane.pos, Pos.mul(Dir.toOffset[dir], length))
    end

    while i <= length+1 do
      -- Don't worry about obstructions when doing corners - old belts are there that would count as obstructions, and
      -- we want to replace them to reorient them.
      local inCorner = (lane.cornerLength and i <= lane.cornerLength)
      if not inCorner and isObstructed(player, beltPosAt(i), dir) then
        if #belts > 0 and belts[#belts].proto == undergroundProto then
          return false
        end
        belts[#belts] = {proto=undergroundProto, type="input", pos=beltPosAt(i-1)}
        local j = i+1
        while j < length+1 and (isObstructed(player, beltPosAt(j), dir) or isObstructed(player, beltPosAt(j+1), dir)) do
          j = j + 1
        end
        if j < length+1 and j-i < undergroundProto.max_underground_distance then
          belts[#belts+1] = {proto=undergroundProto, type="output", pos=beltPosAt(j)}
          i = j+1
        else
          return false
        end
      else
        belts[#belts+1] = {proto=beltProto, pos=beltPosAt(i)}
        i = i + 1
      end
    end
  end

  return {lastPos=lastPos, belts=belts}
end

-- Returns true if building a belt on the given tile would fail.
-- Ignores existing belts facing the same direction.
function isObstructed(player, pos, dir)
  if player.surface.can_place_entity{name = "transport-belt", position = pos, direction = dir} then
    return false
  end
  for _, e in pairs(player.surface.find_entities{pos, Pos.add(pos, {x=.5,y=.5})}) do
    local proto = e.name == "entity-ghost" and e.ghost_prototype or e.prototype
    if proto.belt_speed and e.direction == dir then
      return false
    elseif proto.collision_mask and proto.collision_mask["object-layer"] then
      -- debug(player, "obstruction at %d,%d: %s", pos.x, pos.y, e.name)
      return true
    else
      debug(player, "ignoring non-collider at %d,%d: %s", pos.x, pos.y, e.name)
    end
  end
  return false
end

-- Given a list of planned belts (output of planBelts), actually place them in the world.
function placeBelts(player, belts, dir)
  for i,belt in pairs(belts) do
    placeBelt(player, belt.proto, belt.pos, dir, belt.type)
  end
end

-- p.surface.create_entity{name="orange-arrow-with-circle", position={x,y}, direction=defines.direction.north, force=p.force, player=p}
-- Place a single belt at the position, or a ghost if we're all out.
function placeBelt(player, beltProto, pos, dir, optType)
  if player.can_place_entity{name = beltProto.name, position = pos, direction = dir} and
    player.get_item_count(beltProto.name) > 0 then
      player.surface.create_entity{
        name=beltProto.name,
        position=pos,
        direction=dir,
        force=player.force,
        player=player,
        fast_replace=true,
        type=optType
      }
      player.remove_item{name=beltProto.name, count=1}
  else
    placeGhost(player, beltProto, pos, dir, optType)
  end
end

-- Place a ghost of the given belt type.
function placeGhost(player, beltProto, pos, dir, optType)
  local existing = player.surface.find_entities{pos, Pos.add(pos, {x=.1,y=.1})}
  if existing[1] and
    ((existing[1].name == beltProto.name) or
     (existing[1].name == "entity-ghost" and existing[1].ghost_prototype.name == beltProto.name)) and
     existing[1].direction ~= dir then
    player.surface.deconstruct_area{area={pos, Pos.add(pos, {x=.1,y=.1})}, force=player.force, player=player}
  -- existingGhost[1].destroy()
  end
  player.surface.create_entity{
    name="entity-ghost",
    inner_name=beltProto.name,
    position=pos,
    direction=dir,
    force=player.force,
    player=player,
    fast_replace=true,
    type=optType,
  }
end

-- Returns the corresponding underground belt EntityPrototype for the given belt EntityPrototype.
local speedToUnderground = nil
function getUndergroundForBelt(beltProto)
  if not speedToUnderground then
    speedToUnderground = {}
    for _, ip in pairs(game.item_prototypes) do
      local ep = ip.place_result
      if ep and ep.belt_speed and ep.max_underground_distance then
        speedToUnderground[ep.belt_speed] = ep
      end
    end
  end
  return speedToUnderground[beltProto.belt_speed]
end

function centerDetectorsAt(player, pos)
  local radius = 10
  local _, pdata = Player.get(player.index)

  destroyDetectors(player)

  for x = -radius, radius do
    for y = -radius, radius do
      local entity = player.surface.create_entity{
        name="quickbelt-cursor-detector",
        position=Pos.add(pos, {x=x, y=y}),
        direction=Dir.N,
        force=player.force,
        player=player
      }
      if x == 0 and y == 0 then
        pdata.centerDetector = entity
      end
    end
  end

end

function destroyDetectors(player)
  local entities = player.surface.find_entities_filtered{name="quickbelt-cursor-detector"}
  for _, e in pairs(entities) do
    e.destroy()
  end
end

local kMarkerColor = {0,1,1}
function drawMarkersTo(player, destPos)
  local _, pdata = Player.get(player.index)

  for _, id in pairs(pdata.markers or {}) do
    rendering.destroy(id)
  end
  pdata.markers = nil

  if destPos == nil then
    return
  end

  local lastEntity = findEntity(player, pdata.lastBelt.proto.name, pdata.lastBelt.pos)
  if not (lastEntity and lastEntity.valid) then
    debug(player, "couldn't find previous belt %s at %d,%d", pdata.lastBelt.proto.name, pdata.lastBelt.pos.x, pdata.lastBelt.pos.y)
    return
  end

  local dir = Dir.getPrimary(pdata.lastBelt.pos, destPos)
  local laneInfo = findParallelLanes(player, pdata.lastBelt.proto, lastEntity)
  local lanes = planLanes(player, laneInfo.leftTop, laneInfo.count, lastEntity.direction, dir)
  local rv = planBelts(player, pdata.lastBelt.proto, lanes, dir, destPos)
  if not rv then
    return
  end

  local markers = {}
  for _,belt in pairs(rv.belts) do
    markers[#markers+1] = rendering.draw_sprite{
      sprite = 'quickbelt-marker',
      tint = kMarkerColor,
      orientation = Dir.toOrientation[dir],
      target = Pos.add(belt.pos, {x=.5, y=.5}),
      surface = player.surface,
      players = {player.index},
    }
  end
  pdata.markers = markers
end

local modIsPlacing = false
script.on_event(defines.events.on_built_entity, function(event)
  local player, pdata = Player.get(event.player_index)
  local pos = event.created_entity.bounding_box.left_top
  local proto = event.created_entity.prototype
  local lastBelt = pdata.lastBelt

  -- Ignore events generated by this mod itself.
  if pdata.modIsPlacing then return end
  -- Ignore non-item placements (e.g. a blueprint, undo, etc).
  if not event.item then return end

  if event.created_entity.name == "entity-ghost" then
    proto = event.created_entity.ghost_prototype
    if proto.type ~= "transport-belt" then return end

    if lastBelt then
      local lastEntity = findEntity(player, lastBelt.proto.name, lastBelt.pos)
      if not (lastEntity and lastEntity.valid) then
        debug(player, "couldn't find previous belt %s at %d,%d", lastBelt.proto.name, lastBelt.pos.x, lastBelt.pos.y)
        return
      end

      local dir = Dir.getPrimary(lastBelt.pos, pos)
      local laneInfo = findParallelLanes(player, proto, lastEntity)
      local lanes = planLanes(player, laneInfo.leftTop, laneInfo.count, lastEntity.direction, dir)

      event.created_entity.destroy() -- remove the ghost entity first; may invalidate lastEntity
      local rv = planBelts(player, proto, lanes, dir, pos)
      if not rv then
        player.print("Cannot find a clear path to place belts.")
        return
      end

      pdata.modIsPlacing = true
      placeBelts(player, rv.belts, dir)
      pdata.modIsPlacing = false
      pos = rv.lastPos
    end
  elseif proto.type ~= "transport-belt" then
    return
  end

  pdata.lastBelt = { proto = proto, pos = pos }
end,
{{filter = "transport-belt-connectable"}, {filter = "ghost"}})

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player, pdata = Player.get(event.player_index)

  pdata.isPlacing = false
  if pdata.lastBelt and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
    local cursorEntity = player.cursor_stack.prototype.place_result
    if cursorEntity and cursorEntity.belt_speed then
      pdata.isPlacing = true
      centerDetectorsAt(player, player.position)
      return
    end

    -- Not a belt, end placement mode.
    pdata.lastBelt = nil
  end

  destroyDetectors(player)
end)

script.on_event(defines.events.on_selected_entity_changed, function(event)
  local player, pdata = Player.get(event.player_index)
  if pdata.isPlacing and player.selected and player.selected ~= pdata.centerDetector then
    local destPos = player.selected.bounding_box.left_top
    drawMarkersTo(player, destPos)
    centerDetectorsAt(player, destPos)
  end
end)



-- TODO:
-- reuse detectors in overlapping boundary
-- clear drawing path
-- use picker markers