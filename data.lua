
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
    name = "quickbelt-cursor-detector",
    collision_box = nil,
    collision_mask = {},
    selection_box = {{0, 0}, {1.0, 1.0}},
    order = "zzz-invis-entity",
    picture =
    {
      filename = "__QuickBelt__/assets/transparent.png",
      priority = "extra-high",
      width = 42,
      height = 42,
      shift = {.5, .5},
    },
  },
})