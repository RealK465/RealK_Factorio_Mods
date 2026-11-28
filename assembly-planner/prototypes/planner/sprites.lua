-- The titlebar toggle for unresearched items wears vanilla's white technology flask. Vanilla's
-- own sprite draws the flask in the middle half of a 64 px canvas, so a 24 px titlebar button
-- shrinks it to half the close cross beside it; this one is cropped to the flask.
data:extend({
  {
    type = "sprite",
    name = "apl-show-all",
    filename = "__core__/graphics/icons/mip/technology-white.png",
    position = { 16, 16 },
    size = 32,
    flags = { "gui-icon" },
  },
})
