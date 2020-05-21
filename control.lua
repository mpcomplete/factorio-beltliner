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

function bboxContains(bbox, pos)
  return (pos.x >= bbox.left_top.x and pos.x <= bbox.right_bottom.x and
          pos.y >= bbox.left_top.y and pos.y <= bbox.right_bottom.y)
end

function bboxCenter(bbox)
  return Pos.mul(Pos.add(bbox.left_top, bbox.right_bottom), 0.5)
end

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
function findParallelLanes(player, entity)
  local _, pdata = Player.get(player.index)
  local pos = entity.bounding_box.left_top
  local offset = Dir.toOffset[Dir.R[entity.direction]]
  local lanes = {}

  lanes[1] = {pos = pos, beltProto = entity.prototype}
  for neg=0,1 do
    local sign = neg == 0 and -1 or 1
    for i=1,100 do
      local newPos = Pos.add(pos, Pos.mul(offset, sign*i))
      local e = findEntity(player, entity.prototype.name, newPos)
      if e and e.direction == entity.direction then
        lanes[#lanes+1] = {pos = newPos, beltProto = entity.prototype}
      else
        break
      end
    end
  end

  return lanes
end

-- Returns the top-left position of the last set of belts placed, number of lanes, and direction they are headed.
function getLastPlacedLaneInfo(player)
  local _, pdata = Player.get(player.index)
  assert(pdata.lastPlacedBelt, "Invalid mod state")
  local result = {leftTop = pdata.lastPlacedBelt.pos, numLanes = #pdata.lastPlacedBelt.lanes, dir = pdata.lastPlacedBelt.dir}
  for i, lane in pairs(pdata.lastPlacedBelt.lanes) do
    if lane.pos.x < result.leftTop.x or lane.pos.y < result.leftTop.y then
      result.leftTop = lane.pos
    end
  end

  return result
end

-- Plan the start position for each lane of belts, potentially handling a corner.
-- `targetDir` is the direction the belts will go in.
function planLaneStarts(player, targetDir)
  local _, pdata = Player.get(player.index)
  local laneStarts = {}
  local laneInfo = getLastPlacedLaneInfo(player)
  local startDir = laneInfo.dir

  if Dir.isParallel(startDir, targetDir) then
    local perpendicularOffset = Dir.toOffset[Dir.abs[Dir.R[targetDir]]] -- N/S to E, E/W to S.
    local curPos = laneInfo.leftTop
    for i=1,laneInfo.numLanes do
      laneStarts[i] = {pos = curPos}
      curPos = Pos.add(curPos, perpendicularOffset)
    end
  else
    -- If we're turning east or south, then the top left is the furthest belt. Otherwise, the bottom left is.
    local curPos = (targetDir == Dir.E or targetDir == Dir.S) and
      laneInfo.leftTop or
      Pos.add(laneInfo.leftTop, Pos.mul(Dir.toOffset[targetDir], -(laneInfo.numLanes-1)))

    if pdata.beltReverse then
      -- If we're reversing belts, then the laneStarts actually represent the end of the the lane.
      -- So we have to handle the corner in the opposite direction. startDir is reversed, and we end
      -- the lane a tile earlier so the existing belt follows the corner.
      curPos = Pos.add(curPos, Dir.toOffset[targetDir])
      startDir = Dir.R[Dir.R[startDir]]
    end

    for i=1,laneInfo.numLanes do
      laneStarts[i] = {pos = curPos, cornerLength = laneInfo.numLanes - i + 1}
      curPos = Pos.add(curPos, Dir.toOffset[targetDir])
      curPos = Pos.sub(curPos, Dir.toOffset[startDir])
    end
  end

  return laneStarts
end

-- Plan belts to use in a straight line from startPos to targetPos, using undergrounds to jump over obstacles.
-- TODO: configure undergrounding strategy.
function planBelts(player, beltProto, startPos, targetPos)
  local _, pdata = Player.get(player.index)
  local undergroundProto = getUndergroundForBelt(beltProto)
  local perpendicularOffset = Dir.toOffset[Dir.abs[Dir.R[dir]]] -- N/S to E, E/W to S.
  local targetDir = Dir.getPrimary(startPos, targetPos)

  -- Find the start positions for each lane.
  local laneStarts = planLaneStarts(player, targetDir)

  local belts = {}
  local laneEnds = {}

  for laneIdx,lane in pairs(laneStarts) do
    local length = Pos.proj(Pos.sub(targetPos, lane.pos), targetDir)
    local beltPosAt = function(i) return Pos.add(lane.pos, Pos.mul(Dir.toOffset[targetDir], i-1)) end
    local i=1

    while i <= length+1 do
      -- Don't worry about obstructions when doing corners - old belts are there that would count as obstructions, and
      -- we want to replace them to reorient them.
      local inCorner = (lane.cornerLength and i <= lane.cornerLength)
      if not inCorner and isObstructed(player, beltPosAt(i), targetDir) then
        if #belts > 0 and belts[#belts].proto == undergroundProto then
          return nil
        end
        belts[#belts] = {proto=undergroundProto, type=pdata.beltReverse and "output" or "input", pos=beltPosAt(i-1)}
        local j = i+1
        while j < length+1 and (isObstructed(player, beltPosAt(j), targetDir) or isObstructed(player, beltPosAt(j+1), targetDir)) do
          j = j + 1
        end
        if j < length+1 and j-i < undergroundProto.max_underground_distance then
          belts[#belts+1] = {proto=undergroundProto, type=pdata.beltReverse and "input" or "output", pos=beltPosAt(j)}
          i = j+1
        else
          return nil
        end
      else
        belts[#belts+1] = {proto=beltProto, pos=beltPosAt(i)}
        i = i + 1
      end
    end

    -- Last belt we placed is the end of this lane.
    laneEnds[laneIdx] = belts[#belts]
  end

  return {
    belts = belts,
    laneEnds = laneEnds,
    beltDir = pdata.beltReverse and Dir.R[Dir.R[targetDir]] or targetDir
  }
end

-- Returns true if building a belt on the given tile would fail.
-- Ignores existing belts facing a parallel direction.
-- TODO: should do better about distinguishing obstacles with existing belts we can replace.
function isObstructed(player, pos, dir)
  if player.surface.can_place_entity{name = "transport-belt", position = pos, direction = dir} then
    return false
  end
  for _, e in pairs(player.surface.find_entities{pos, Pos.add(pos, {x=.5,y=.5})}) do
    local proto = e.name == "entity-ghost" and e.ghost_prototype or e.prototype
    if (proto.type == "transport-belt" or proto.type == "underground-belt") and Dir.isParallel(e.direction, dir) then
      return false
    elseif proto.collision_mask and proto.collision_mask["object-layer"] then
      -- debug(player, "obstruction at %s: %s", Pos.str(pos), e.name)
      return true
    else
      -- debug(player, "ignoring non-collider at %s: %s", Pos.str(pos), e.name)
    end
  end
  return false
end

-- Tries to plan a belt path from `startPos` to `targetPos`, possibly rearranging belts at
-- `startPos` to turn a corner.
-- On success, returns {belts, dir} where belts is an array of {proto, type, pos} used by placeBelts.
function findAndPlanPath(player, beltProto, startPos, targetPos)
  local dir = Dir.getPrimary(startPos, targetPos)
  return planBelts(player, beltProto, lanes, dir, targetPos)
end

-- Given a list of planned belts (output of planBelts), actually place them in the world.
function placeBelts(player, belts, dir)
  for i,belt in pairs(belts) do
    placeBelt(player, belt.proto, belt.pos, dir, belt.type)
  end
end

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

-- Creates a 10x10 square of "detectors" centered at the given position.
-- A detector is an invisible entity that serves as a hacky way to detect when the
-- player's cursor moves position (via the on_selected_entity_changed event).
function centerDetectorsAt(player, pos)
  local kRadius = 10
  local _, pdata = Player.get(player.index)

  local radiusOffset = {x=kRadius, y=kRadius}
  local newBbox = {
    left_top = Pos.sub(pos, radiusOffset),
    right_bottom = Pos.add(pos, radiusOffset)
  }
  local oldBbox
  if pdata.centerDetectorPos then
    -- Remove detectors outside the new region.
    oldBbox = {
      left_top = Pos.sub(pdata.centerDetectorPos, radiusOffset),
      right_bottom = Pos.add(pdata.centerDetectorPos, radiusOffset)
    }
    local entities = player.surface.find_entities_filtered{area=oldBbox, name="quickbelt-cursor-detector"}
    for _, e in pairs(entities) do
      if not bboxContains(newBbox, e.bounding_box.left_top) then e.destroy() end
    end
  end

  pdata.centerDetectorPos = pos
  for x = -kRadius, kRadius do
    for y = -kRadius, kRadius do
      local cellPos = Pos.add(pos, {x=x, y=y})
      if not oldBbox or not bboxContains(oldBbox, cellPos) then
        -- Only create a detector if there's no entity there. If there is, it can act as our detector. This
        -- fixes a bug where entity ghosts would be deleted if the player was standing inside them.
        local entities = player.surface.find_entities_filtered{position=cellPos}
        if #entities == 0 then
          local entity = player.surface.create_entity{
            name="quickbelt-cursor-detector",
            position=cellPos,
            direction=Dir.N,
            force=player.force,
            player=player
          }
        end
      end
    end
  end
end

-- Destroys all detectors created by centerDetectorsAt.
function destroyDetectors(player)
  local _, pdata = Player.get(player.index)
  pdata.centerDetectorPos = nil
  local entities = player.surface.find_entities_filtered{name="quickbelt-cursor-detector"}
  for _, e in pairs(entities) do
    e.destroy()
  end
end

-- Draws a set of markers denoting the path given by `findAndPlanPath` to the targetPos.
-- Does nothing if no path exists.
function drawMarkers(player, targetPos)
  local kMarkerColor = {0,1,1}
  local kMarkerColorReverse = {1,.6,1}
  local _, pdata = Player.get(player.index)

  destroyMarkers(player)

  if not pdata.lastPlacedBelt then return end  -- shouldn't happen
  local rv = planBelts(player, pdata.lastPlacedBelt.proto, pdata.lastPlacedBelt.pos, targetPos)
  if not rv then
    return
  end

  local markers = {}
  for _,belt in pairs(rv.belts) do
    markers[#markers+1] = rendering.draw_sprite{
      sprite = 'quickbelt-marker',
      tint = pdata.beltReverse and kMarkerColorReverse or kMarkerColor,
      orientation = Dir.toOrientation[rv.beltDir],
      target = Pos.add(belt.pos, {x=.5, y=.5}),
      surface = player.surface,
      players = {player.index},
    }
  end
  pdata.markers = markers
end

-- Destroys all markers currently being drawn.
function destroyMarkers(player)
  local _, pdata = Player.get(player.index)
  for _, id in pairs(pdata.markers or {}) do
    rendering.destroy(id)
  end
  pdata.markers = nil
end

-- Enters belt placement mode, using detectors to keep track of where the cursor is.
function beginPlacementMode(player, beltProto, pos)
  local _, pdata = Player.get(player.index)
  if pdata.isPlacing then return end
  pdata.isPlacing = true
  centerDetectorsAt(player, pos)
end

-- Ends belt placement mode, cleaning up any marker UI and detector entities.
function endPlacementMode(player)
  local _, pdata = Player.get(player.index)
  if not pdata.isPlacing then return end
  pdata.isPlacing = false
  pdata.beltReverse = false
  pdata.lastPlacedBelt = nil
  destroyDetectors(player)
  destroyMarkers(player)
end

script.on_event(defines.events.on_built_entity, function(event)
  local player, pdata = Player.get(event.player_index)
  local pos = event.created_entity.bounding_box.left_top
  local proto = event.created_entity.prototype

  -- Don't do anything if we're disabled.
  if pdata.disabled then return end
  -- Ignore events generated by this mod itself.
  if pdata.modIsPlacing then return end
  -- Ignore non-item placements (e.g. a blueprint, undo, etc).
  if not event.item then return end

  if event.created_entity.name == "entity-ghost" and pdata.lastPlacedBelt then
    proto = event.created_entity.ghost_prototype
    if proto.type ~= "transport-belt" then return end

    local rv = planBelts(player, pdata.lastPlacedBelt.proto, pdata.lastPlacedBelt.pos, pos)
    -- Entity may have been paved over alredy. If not, remove it, since it's only used as a signal to the mod.
    if event.created_entity.valid then event.created_entity.destroy() end
    if not rv then
      player.print("Cannot find a clear path to place belts.")
      return
    end

    pdata.modIsPlacing = true
    placeBelts(player, rv.belts, rv.beltDir)
    pdata.modIsPlacing = false
    pos = rv.belts[#rv.belts].pos
    pdata.lastPlacedBelt = {proto = pdata.lastPlacedBelt.proto, pos = rv.belts[#rv.belts].pos, lanes = rv.laneEnds, dir = rv.beltDir}
  elseif proto.type == "transport-belt" then
    local lanes = findParallelLanes(player, event.created_entity)
    pdata.lastPlacedBelt = {proto = proto, pos = pos, lanes = lanes, dir = event.created_entity.direction}
  else
    return
  end

  beginPlacementMode(player, proto, pos)
end,
{{filter = "transport-belt-connectable"}, {filter = "ghost"}})

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player, pdata = Player.get(event.player_index)

  local cursorEntity = nil
  if player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
    cursorEntity = player.cursor_stack.prototype.place_result
  elseif player.cursor_ghost and player.cursor_ghost.valid then
    cursorEntity = player.cursor_ghost.place_result
  end

  if cursorEntity and cursorEntity.type == "transport-belt" then
    -- beginPlacementMode(player, cursorEntity, player.position)
    return
  end

  endPlacementMode(player)
end)

function updateMarkers(player)
  local _, pdata = Player.get(player.index)
  if pdata.isPlacing and player.selected then
    -- Center = avg of bbox
    local targetPos = bboxCenter(player.selected.bounding_box)
    -- debug(player, "Cursor moved: %s", Pos.str(targetPos))
    drawMarkers(player, targetPos)
    centerDetectorsAt(player, targetPos)
  end
end

script.on_event(defines.events.on_selected_entity_changed, function(event)
  local player, pdata = Player.get(event.player_index)
  if pdata.isPlacing then
    updateMarkers(player)
  end
end)

script.on_event("quickbelt-reverse", function(event)
  local player, pdata = Player.get(event.player_index)
  if pdata.isPlacing then
    pdata.beltReverse = not pdata.beltReverse
    updateMarkers(player)
  end
end)

script.on_event("quickbelt-toggle", function(event)
  local player, pdata = Player.get(event.player_index)
  pdata.disabled = not pdata.disabled
  player.print("Quickbelt placement is now " .. (pdata.disabled and "disabled" or "enabled"))
  if pdata.disabled then 
    endPlacementMode(player)
  end
end)