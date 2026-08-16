-- Research-state helpers for the in-game suite: the journal's five harness states as one API.
-- Every spec sets its state explicitly (states persist across tests in one run), and always on
-- the force it is handed -- tests never assume a state left behind by an earlier file.

local research = {}

-- Day-one force: no technologies, initial recipes only. force.reset() restores recipes too,
-- which is what makes it a real "fresh" rather than "researched but with recipes left enabled".
function research.fresh(force)
  force.reset()
end

function research.full(force)
  force.research_all_technologies()
end

-- Exactly these technologies researched, nothing else. Setting .researched does not pull in
-- prerequisites -- deliberate, it is what lets "recycling-only" exist at all (the state that
-- exposed the producer-guard bugs, journal 2026-08-15).
function research.only(force, techs)
  force.reset()
  for _, name in ipairs(techs) do
    force.technologies[name].researched = true
  end
end

-- The cheat-mode state from the H1 matrix: every recipe force-enabled with no research at all,
-- which is what editor sessions look like and what the Factoriopedia-hidden guard exists for.
function research.cheat(force)
  force.reset()
  force.enable_all_recipes()
end

function research.enable_recipe(force, name)
  force.recipes[name].enabled = true
end

return research
