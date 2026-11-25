-- Research-state helpers for the in-game suite. Every spec sets its state explicitly (states
-- persist across tests in one run), on the force it is handed. Copied from Upcycler Planner.

local research = {}

-- Day-one force: no technologies, initial recipes only.
function research.fresh(force)
  force.reset()
end

function research.full(force)
  force.research_all_technologies()
end

-- Exactly these technologies researched, nothing else; prerequisites are not pulled in.
function research.only(force, techs)
  force.reset()
  for _, name in ipairs(techs) do
    force.technologies[name].researched = true
  end
end

return research
