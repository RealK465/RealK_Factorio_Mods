-- Luacheck for every mod in this repo, Factorio 2.1 names (the community's old 0.18-era
-- Factorio luacheckrc is dead; this is the modern minimal set). Catches undefined globals --
-- which is exactly what the 2.0 renames turn stale code into -- and unused locals; field-level
-- API checking is emmylua_check's job (factorio-testing skill).
std = "lua52c"

-- Style is the review's job, not this file's; the only hard rule here is correctness.
max_line_length = false

read_globals = {
  -- control stage
  "game", "script", "remote", "commands", "rendering", "rcon", "helpers", "prototypes",
  "defines", "settings", "serpent", "log", "localised_print", "table_size", "util",
  -- data stage
  "data", "mods", "feature_flags",
}

-- The one global a mod writes.
globals = { "storage" }

-- factorio-test's surface, visible only to spec files.
files["**/tests/**"] = {
  read_globals = {
    "describe", "test", "it", "before_all", "after_all", "before_each", "after_each",
    "after_test", "async", "done", "on_tick", "after_ticks", "tags",
  },
}

exclude_files = {
  "exemples",
  ".claude/skills/factorio-testing/typedefs",
  "assets",
}
