local defs = require("prototypes.modules.definitions")

local modules = {}
for _, def in pairs(defs) do
  -- Take the inventory sounds off the tier-3 module this one follows, rather
  -- than requiring base's item-sounds file: nested relative requires inside
  -- __base__ resolve against this mod and break.
  local parent = data.raw["module"][def.parent_item]

  modules[#modules + 1] = {
    type = "module",
    name = def.name,
    icon = "__pure-modules-realk__/graphics/icons/" .. def.name .. ".png",
    subgroup = "module",
    color_hint = { text = def.color_hint },
    category = def.category,
    tier = 4,
    order = def.order,
    stack_size = 50,
    weight = 20 * kg,
    effect = def.effect,
    beacon_tint = def.beacon_tint,
    -- Draws the vanilla module graphic tinted by beacon_tint when slotted
    -- into a beacon, so Pure modules show up there without their own art.
    art_style = "vanilla",
    requires_beacon_alt_mode = false,
    inventory_move_sound = parent and parent.inventory_move_sound,
    pick_sound = parent and parent.pick_sound,
    drop_sound = parent and parent.drop_sound,
  }
end

data:extend(modules)
