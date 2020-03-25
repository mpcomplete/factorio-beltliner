
local belt_sprite_prototypes = {}
do
    local i = 1
    for x = 0, 512 - 32, 32 do
        belt_sprite_prototypes[i] = {
            type = 'sprite',
            name = 'quickbelt-marker-' .. i,
            width = 32,
            height = 32,
            x = x,
            y = 0,
            filename = '__PickerBeltTools__/graphics/entity/markers/belt-arrows.png'
        }
        i = i + 1
    end
end

data:extend(belt_sprite_prototypes)

data:extend({
  {
    type = "simple-entity",
    name = "belt-invis-entity",
    -- selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    selection_box = {{0, 0}, {1.0, 1.0}},
    order = "zzz-invis-entity",
    -- flags = {"placeable-neutral", "player-creation"},
    picture =
    {
      filename = "__base__/graphics/entity/wooden-chest/wooden-chest.png",
      priority = "extra-high",
      width = 32,
      height = 36,
      shift = {.5, .5},
    },
  },
})