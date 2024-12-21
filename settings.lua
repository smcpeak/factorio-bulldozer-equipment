-- settings.lua
-- Configuration settings.

data:extend({
  -- Diagnostic log verbosity level.  See `diagnostic_verbosity` in
  -- control.lua.
  {
    type = "int-setting",
    name = "bulldozer-equipment-diagnostic-verbosity",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 0,
    maximum_value = 5,
  },

  -- Time between checks for nearby obstacles.
  {
    type = "int-setting",
    name = "bulldozer-equipment-check-period-ticks",
    setting_type = "runtime-global",
    default_value = 15,
    minimum_value = 1,
    maximum_value = 300,
  },

  -- Time between checks for a landfill blueprint.
  {
    type = "int-setting",
    name = "bulldozer-equipment-refresh-landfill-blueprint-period-ticks",
    setting_type = "runtime-global",
    default_value = 300,
    minimum_value = 1,
    maximum_value = 3600,
  },

  -- Maximum distance to a "nearby" obstacle entity.
  {
    type = "int-setting",
    name = "bulldozer-equipment-obstacle-entity-radius",
    setting_type = "runtime-global",
    default_value = 16,
    minimum_value = 1,
    maximum_value = 100,
  },

  -- Maximum distance to a "nearby" obstacle tile.
  {
    type = "int-setting",
    name = "bulldozer-equipment-obstacle-tile-radius",
    setting_type = "runtime-global",
    default_value = 8,
    minimum_value = 1,
    maximum_value = 100,
  },

  -- Whether to do anything for this player.
  {
    type = "bool-setting",
    name = "bulldozer-equipment-enable-for-player",
    setting_type = "runtime-per-user",
    default_value = true,
  },
});


-- EOF
