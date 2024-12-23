-- settings.lua
-- Configuration settings.

data:extend({
  -- ------------------------- Global settings -------------------------
  -- Call the error() function when a bug is detected?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-call-error-on-bug",
    setting_type = "runtime-global",
    default_value = false,
  },

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
    name = "bulldozer-equipment-obstacle-check-period-ticks",
    setting_type = "runtime-global",
    default_value = 15,
    minimum_value = 0,
    maximum_value = 300,
  },

  -- Time between landfill creation operations.
  {
    type = "int-setting",
    name = "bulldozer-equipment-landfill-creation-period-ticks",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 0,
    maximum_value = 3600,
  },

  -- ----------------------- Per-player settings -----------------------
  -- Whether to do anything for this player.
  {
    type = "bool-setting",
    name = "bulldozer-equipment-enable-for-player",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Maximum distance to a "nearby" obstacle entity.
  {
    type = "int-setting",
    name = "bulldozer-equipment-obstacle-entity-radius",
    setting_type = "runtime-per-user",
    default_value = 16,
    minimum_value = 1,
    maximum_value = 100,
  },

  -- Maximum distance to a "nearby" obstacle tile.
  {
    type = "int-setting",
    name = "bulldozer-equipment-obstacle-tile-radius",
    setting_type = "runtime-per-user",
    default_value = 8,
    minimum_value = 1,
    maximum_value = 100,
  },

  -- Remove trees?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-remove-trees",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Remove rocks?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-remove-rocks",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Remove cliffs?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-remove-cliffs",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Remove water?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-remove-water",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Convert wood into landfill?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-landfill-from-wood",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Convert coal into landfill?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-landfill-from-coal",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  -- Convert stone into landfill?
  {
    type = "bool-setting",
    name = "bulldozer-equipment-want-landfill-from-stone",
    setting_type = "runtime-per-user",
    default_value = true,
  },
});


-- EOF
