-- The item the player gets in their cursor after pressing Confirm. It answers one question --
-- where the layout goes -- so it selects ground, not entities.
--
-- `mode = {"any-tile"}` rather than {"nothing"}: a selection has to be non-empty for
-- on_player_selected_area to fire, and tiles are the one thing guaranteed to be under the
-- cursor. A single click yields a one-tile area, which is the same code path as a drag.
--
-- `only-in-cursor` is what makes Q throw the tool away instead of stuffing it into the
-- player's inventory -- it has no use outside the cursor and should not survive leaving it.
-- `spawnable` is required for anything script puts in a cursor.
--
-- Both select and alt_select are mandatory on the prototype even though only the plain one is
-- handled; alt gets the same behaviour rather than a second meaning it does not have yet.

local icons = require("prototypes.planner.icons")

local select_behaviour = {
  border_color = { r = 0.3, g = 0.8, b = 1 },
  cursor_box_type = "copy",
  mode = { "any-tile" },
}

data:extend({
  {
    type = "selection-tool",
    name = "ua-planner",
    icons = icons,
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    subgroup = "other",
    order = "c[automated-construction]-u[upcycler-architect]",
    stack_size = 1,
    select = select_behaviour,
    alt_select = select_behaviour,
  },
})
