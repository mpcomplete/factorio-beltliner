data:extend({
  -- Shortcut keys
  {
    type = "custom-input",
    name = "beltliner-reverse",
    key_sequence = "CTRL+SHIFT+R",
    -- linked_game_control = "reverse-rotate",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "beltliner-toggle",
    key_sequence = "CTRL+SHIFT+B",
    consuming = "none"
  },
  -- An invisible entity used for detecting where the mouse cursor is.
  {
    type = "simple-entity",
    name = "beltliner-cursor-detector",
    collision_box = nil,
    collision_mask = {},
    selection_box = {{0, 0}, {1.0, 1.0}},
    order = "zzz-invis-entity",
    picture =
    {
      filename = "__BeltLiner__/assets/transparent.png",
      priority = "extra-high",
      width = 42,
      height = 42,
      shift = {.5, .5},
    },
  },
  -- An sprite used for drawing belt paths. Borrowed from PickerBeltTools.
  {
    type = 'sprite',
    name = 'beltliner-marker',
    width = 32,
    height = 32,
    x = 0,
    y = 0,
    filename = '__BeltLiner__/assets/marker.png'
  },
})
