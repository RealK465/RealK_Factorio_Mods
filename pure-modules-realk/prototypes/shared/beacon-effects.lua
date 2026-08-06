-- What the Pure beacon is allowed to carry. Two files need the same answer --
-- beacon.lua for allowed_effects and the power draw, final-fixes for the
-- module whitelist -- and they must not be able to disagree.
--
-- Quality modules only exist with the quality expansion, so settings.lua does
-- not define that setting without it and the mods check has to come first:
-- indexing a setting that was never defined is an error, not a nil. Same
-- short-circuit shared/aquilo.lua leans on. Productivity needs no such guard,
-- since productivity modules are base game.
--
-- Without the expansion the setting would otherwise still have charged the
-- beacon its extra megawatt, and permanently -- a startup setting locks once a
-- save exists.
return {
  productivity = settings.startup["pure-modules-realk-beacon-allow-productivity"].value,
  quality = mods["quality"] ~= nil
    and settings.startup["pure-modules-realk-beacon-allow-quality"].value,
}
