-- control.lua


-- ------------------------ Configuration data -------------------------
-- How much to log, from among:
--   0: Nothing.
--   1: Only things that indicate a serious problem.  These suggest a
--      bug in this mod, but are recoverable.
--   2: Relatively infrequent things possibly of interest to the user.
--   3: More details, also of potential user interest.
--   4: Individual algorithm steps only of interest to a developer.
--   5: Even more verbose developer details, especially things that
--      happen periodically regardless of anything else.
local diagnostic_verbosity = 5;  -- TODO: Reset to 1.

-- Time between checks for nearby obstacles, in ticks.
local check_period_ticks = 15;

-- Period between attempts to refresh `landfill_blueprint`, in ticks.
--
-- The relevant check is pretty fast, but there's no need to do it
-- often.
--
-- This must be different from `check_period_ticks`.  The code that
-- reads the user's choices compensates when necessary.
--
local refresh_landfill_blueprint_period_ticks = 300;

-- Maximum distance to a "nearby" obstacle entity, in game grid units.
local obstacle_entity_radius = 16;

-- Maximum distance to a "nearby" obstacle tile, in game grid units.
--
-- This is different from the entity radius because, in playtesting,
-- the larger radius seems excessive and obnoxious for tiles, while the
-- smaller radius is not big enough for rocks and trees.  In part,
-- that relates to the much bigger investment in resources required to
-- clear obstacle tiles versus obstacle entities.
--
local obstacle_tile_radius = 8;

-- List of names of tiles we can landfill.
--
-- TODO: Compute this during the prototype stage as
-- `data.item.landfill.place_as_tile.tile_condition`.
--
local landfillable_tile_names = {
  "water",
  "deepwater",
  "water-green",
  "deepwater-green",
  "water-mud",
  "water-shallow",
  --[[
  "wetland-light-green-slime",
  "wetland-green-slime",
  "wetland-light-dead-skin",
  "wetland-dead-skin",
  "wetland-pink-tentacle",
  "wetland-red-tentacle",
  "wetland-yumako",
  "wetland-jellynut",
  "wetland-blue-slime",
  "gleba-deep-lake"
  --]]
};


-- --------------------------- Runtime data ----------------------------
-- LuaRecord of the blueprint to use to order landfill to be
-- constructed.  This is refreshed periodically.  It might become
-- invalid at any time.
--
-- Interestingly, one thing that can invalidate a blueprint reference is
-- adding another blueprint earlier than it to the library, since that
-- affects the internal ID (which cannot be directly queried in the API,
-- but `serpent.line` returns a string including it).
--
local landfill_blueprint = nil;


-- ------------------------- Utility functions -------------------------
-- Log 'str' if we are at verbosity 'v' or higher.
local function diag(v, str)
  if (v <= diagnostic_verbosity) then
    log(str);
  end;
end;


-- Return a BoundingBox centered at `pos` with `radius`.
local function bounding_box_with_radius(pos, radius)
  return {
    left_top = {
      x = pos.x - radius,
      y = pos.y - radius,
    },
    right_bottom = {
      x = pos.x + radius,
      y = pos.y + radius,
    },
  };
end;


-- Return a string describing a map position.
local function pos_str(pos)
  return "(" .. pos.x .. "," .. pos.y .. ")";
end;


-- ------------------------ Mod-specific logic -------------------------
-- Scan near one player for natural obstacles if it has the necessary
-- equipment.
local function player_check_for_obstacles(player)
  if (player.character == nil) then
    diag(5, "Player " .. player.index .. " has no character.");
    return;
  end;

  local equipment_grid = player.character.grid;
  if (equipment_grid == nil) then
    diag(5, "Player " .. player.index .. " has no equipment grid.");
    return;
  end;

  local bulldozer_equipment = equipment_grid.find("bulldozer-equipment");
  if (bulldozer_equipment == nil) then
    diag(5, "Player " .. player.index .. " does not have a bulldozer.");
    return;
  end;

  local required_energy = bulldozer_equipment.max_energy / 2;
  if (bulldozer_equipment.energy < required_energy) then
    diag(4, "Player " .. player.index ..
            " has a bulldozer with " .. bulldozer_equipment.energy ..
            " J, but that is less than the required " .. required_energy ..
            " J, so it is not operational.");
    return;
  end;

  local include_cliffs = player.force.cliff_deconstruction_enabled;

  diag(5, "Player " .. player.index ..
          ": Scanning area within " .. obstacle_entity_radius ..
          " units of " .. pos_str(player.position) ..
          " for obstacle entities, " ..
          (include_cliffs and "including" or "NOT including") ..
          " cliffs.");

  local area = bounding_box_with_radius(player.position, obstacle_entity_radius);
  local types = {"tree", "simple-entity"};
  if (include_cliffs) then
    table.insert(types, "cliff");
  end;

  local entities = player.surface.find_entities_filtered{
    area = area,
    type = types,
  };
  for _, entity in pairs(entities) do
    -- Filter out non-rocks.
    ignore = false;
    if (entity.type == "simple-entity") then
      if (not entity.prototype.count_as_rock_for_filtered_deconstruction) then
        diag(5, "Simple entity at " .. pos_str(entity.position) ..
                ", called \"" .. entity.name ..
                "\", is not a rock, so ignoring.");
        ignore = true;
      end;
    end;

    if (not ignore) then
      -- The factorio API docs for `LuaEntity.to_be_deconstructed` do
      -- not mention being able to pass a "force" argument.  I think
      -- that means what I pass here will simply be ignored, but it is
      -- possible that in fact it is accepted and respected, like for
      -- tiles.
      if (not entity.to_be_deconstructed(player.force)) then
        diag(3, "Ordering deconstruction of " .. entity.name ..
                " at " .. pos_str(entity.position) .. ".");
        entity.order_deconstruction(player.force, player);
      else
        diag(4, "Not ordering deconstruction of " .. entity.name ..
                " at " .. pos_str(entity.position) ..
                " because it is already marked.");
      end;
    end;
  end;

  if (landfill_blueprint ~= nil and landfill_blueprint.valid) then
    diag(5, "Player " .. player.index ..
            ": Scanning area within " .. obstacle_tile_radius ..
            " units of " .. pos_str(player.position) ..
            " for obstacle tiles.");

    area = bounding_box_with_radius(player.position, obstacle_tile_radius);

    local tiles = player.surface.find_tiles_filtered{
      area = area,
      name = landfillable_tile_names,
      has_tile_ghost = false,
      force = player.force,
    };
    for _, tile in pairs(tiles) do
      diag(3, "Ordering landfill of " .. tile.name ..
              " tile at " .. pos_str(tile.position) .. ".");
      landfill_blueprint.build_blueprint{
        surface = player.surface,
        force = player.force,
        position = tile.position,
        raise_built = true,
      };
    end;
  end;
end;


-- Scan the areas near all players.
local function all_players_check_for_obstacles()
  for _, player in pairs(game.players) do
    player_check_for_obstacles(player);
  end;
end;

-- Try to find a blueprint to use from the game library.
local function refresh_landfill_blueprint()
  diag(5, "Refreshing the landfill blueprint.");
  local chosen_blueprint = nil;

  for _, blueprint in pairs(game.blueprints) do
    if (blueprint.type == "blueprint") then
      -- Require that it have no entities.
      local entity_count = blueprint.get_blueprint_entity_count();
      if (entity_count ~= 0) then
        diag(5, "Ignoring blueprint with " .. entity_count ..
                " entities.");
        break;
      end;

      -- Require that it have exactly one landfill tile.
      local num_landfill_tiles = 0;
      local bptiles = blueprint.get_blueprint_tiles();
      if (bptiles ~= nil) then
        for _, bptile in pairs(bptiles) do
          if (bptile.name == "landfill") then
            num_landfill_tiles = num_landfill_tiles + 1;
          end;
        end;

        if (num_landfill_tiles == 1) then
          diag(5, "Found a blueprint with one landfill tile, using it.");
          chosen_blueprint = blueprint;
          break;

        else
          diag(5, "Found a blueprint with " .. num_landfill_tiles ..
                  " landfill tiles, ignoring.");

        end;

      else
        diag(5, "Found a blueprint with no tiles or entities.");

      end;
    end;
  end;

  if (chosen_blueprint ~= landfill_blueprint) then
    diag(2, "Changing landfill blueprint from " .. serpent.line(landfill_blueprint) ..
            " to " .. serpent.line(chosen_blueprint) .. ".");
    landfill_blueprint = chosen_blueprint;
  end;
end;


-- Re-read the configuration settings.
--
-- Below, this is done once on startup, then afterward in response to
-- the on_runtime_mod_setting_changed event.
--
local function read_configuration_settings()
  -- Note: Because the diagnostic verbosity is changed here, it is
  -- possible to see unpaired "begin" or "end" in the log.
  diag(4, "read_configuration_settings begin");

  -- Clear any existing tick handlers.
  script.on_nth_tick(nil);

  --diagnostic_verbosity                    = settings.global["bulldozer-module-diagnostic-verbosity"].value;
  --check_period_ticks                      = settings.global["bulldozer-module-check-period-ticks"].value;
  --refresh_landfill_blueprint_period_ticks = settings.global["bulldozer-module-refresh-landfill-blueprint-period-ticks"].value;
  --obstacle_entity_radius                  = settings.global["bulldozer-module-obstacle-entity-radius"].value;
  --obstacle_tile_radius                    = settings.global["bulldozer-module-obstacle-tile-radius"].value;

  -- The API uses the period as an identifier of the registered
  -- handlers, so it is awkward to register two handlers with the same
  -- period.  Adjust the less important one to make them different.
  if (check_period_ticks == refresh_landfill_blueprint_period_ticks) then
    refresh_landfill_blueprint_period_ticks =
      refresh_landfill_blueprint_period_ticks + 1;
  end;

  -- Re-establish the tick handlers with the new periods.
  script.on_nth_tick(check_period_ticks, function(e)
    all_players_check_for_obstacles();
  end);
  script.on_nth_tick(refresh_landfill_blueprint_period_ticks, function(e)
    refresh_landfill_blueprint();
  end);

  diag(4, "read_configuration_settings end");
end;


-- -------------------------- Initialization ---------------------------
read_configuration_settings();


-- EOF
