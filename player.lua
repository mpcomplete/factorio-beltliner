local Player = {}

function Player.get(player_index)
  global = global or {}
  global.perplayer = global.perplayer or {}
  global.perplayer[player_index] = global.perplayer[player_index] or {}
  return game.players[player_index], global.perplayer[player_index]
end

function Player.destroy(player_index)
  if global and global.perplayer then
    global.perplayer[player_index] = nil
  end
end

script.on_event(defines.events.on_player_left_game, function(event)
  Player.destroy(event.player_index)
end)

return Player