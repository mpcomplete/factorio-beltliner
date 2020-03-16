local Global = {}

function Global.get(player)
  global = global or {}
  global.perplayer = global.perplayer or {}
  global.perplayer[player.index] = global.perplayer[player.index] or {}
  return global.perplayer[player.index]
end

function Global.destroy(player_index)
  if global and global.perplayer then
    global.perplayer[player_index] = nil
  end
end

script.on_event(defines.events.on_player_left_game, function(event)
  Global.destroy(event.player_index)
end)

return Global