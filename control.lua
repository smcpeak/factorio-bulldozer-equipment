-- control.lua


-- ------------------------ Configuration data -------------------------
-- The default values in this section are overwritten when the user
-- settings are read, but for convenience, these values are the same
-- as the default setting values.

-- How much to log, from among:
--   0: Nothing.
--   1: Only things that indicate a serious problem.  These suggest a
--      bug in this mod, but are recoverable.
--   2: Relatively infrequent things possibly of interest to the user.
--   3: More details, also of potential user interest.
--   4: Individual algorithm steps only of interest to a developer.
--   5: Even more verbose developer details, especially things that
--      happen periodically regardless of anything else.
local diagnostic_verbosity = 1;

-- Time between checks for nearby obstacles, in ticks.  0 disables.
local obstacle_check_period_ticks = 15;

-- Time between landfill creation operations, in ticks.  0 disables.
local landfill_creation_period_ticks = 60;

-- Maximum distance to a "nearby" obstacle entity, in game grid units.
local obstacle_entity_radius = 16;

-- Maximum distance to a "nearby" obstacle tile, in game grid units.
--
-- This is different from the entity radius because, in playtesting, the
-- larger radius seems excessive and obnoxious for tiles, while the
-- smaller radius is not big enough for rocks and trees.  In part, that
-- relates to the much bigger investment in time and resources required
-- to clear obstacle tiles versus obstacle entities.
--
local obstacle_tile_radius = 8;

-- Whether to clear each specific obstacle.
local want_remove_trees = true;
local want_remove_rocks = true;
local want_remove_cliffs = true;
local want_remove_water = true;


-- --------------------------- Runtime data ----------------------------
-- List of names of tiles we can landfill.  Set below, during
-- initialization.
local landfillable_tile_names = {};

-- For each player, the most recent tick on which they moved.
local player_index_to_last_move_tick = {};


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
-- True if `actor_entity` has the bulldozer equipment installed and it
-- has sufficient power.
local function entity_has_bulldozer(actor_entity)
  local actor_entity_desc =
    actor_entity.name .. " " .. actor_entity.unit_number;

  local equipment_grid = actor_entity.grid;
  if (equipment_grid == nil) then
    diag(5, actor_entity_desc .. " has no equipment grid.");
    return false;
  end;

  local bulldozer_equipment = equipment_grid.find("bulldozer-equipment");
  if (bulldozer_equipment == nil) then
    diag(5, actor_entity_desc .. " does not have a bulldozer.");
    return false;
  end;

  local required_energy = bulldozer_equipment.max_energy / 2;
  if (bulldozer_equipment.energy < required_energy) then
    diag(3, actor_entity_desc ..
            " has a bulldozer with " .. bulldozer_equipment.energy ..
            " J, but that is less than the required " .. required_energy ..
            " J, so it is not operational.");
    return false;
  end;

  return true;
end;


-- Scan near one entity for natural obstacles if it has the necessary
-- equipment.
local function entity_check_for_obstacles(actor_entity)
  if (not entity_has_bulldozer(actor_entity)) then
    return;
  end;

  local actor_entity_desc =
    actor_entity.name .. " " .. actor_entity.unit_number;

  local force = actor_entity.force;
  local surface = actor_entity.surface;

  local include_cliffs = want_remove_cliffs and force.cliff_deconstruction_enabled;
  if (want_remove_trees or
      want_remove_rocks or
      include_cliffs) then
    local types = {};
    if (want_remove_trees) then
      table.insert(types, "tree");
    end;
    if (want_remove_rocks) then
      table.insert(types, "simple-entity");
    end;
    if (include_cliffs) then
      table.insert(types, "cliff");
    end;

    diag(5, actor_entity_desc ..
            ": Scanning area within " .. obstacle_entity_radius ..
            " units of " .. pos_str(actor_entity.position) ..
            " for obstacle entities: " .. serpent.line(types));

    local area = bounding_box_with_radius(actor_entity.position, obstacle_entity_radius);

    local obstacle_entities = surface.find_entities_filtered{
      area = area,
      type = types,
    };
    for _, obstacle_entity in pairs(obstacle_entities) do
      -- Filter out non-rocks.
      ignore = false;
      if (obstacle_entity.type == "simple-entity") then
        if (not obstacle_entity.prototype.count_as_rock_for_filtered_deconstruction) then
          diag(5, "Simple entity at " .. pos_str(obstacle_entity.position) ..
                  " called \"" .. obstacle_entity.name ..
                  "\" is not a rock, so ignoring.");
          ignore = true;
        end;
      end;

      if (not ignore) then
        -- The factorio API docs for `LuaEntity.to_be_deconstructed` do
        -- not mention being able to pass a "force" argument.  I think
        -- that means what I pass here will simply be ignored, but it is
        -- possible that in fact it is accepted and respected, like for
        -- tiles.
        if (not obstacle_entity.to_be_deconstructed(force)) then
          diag(3, "Ordering deconstruction of " .. obstacle_entity.name ..
                  " at " .. pos_str(obstacle_entity.position) .. ".");
          obstacle_entity.order_deconstruction(force);
        else
          diag(4, "Not ordering deconstruction of " .. obstacle_entity.name ..
                  " at " .. pos_str(obstacle_entity.position) ..
                  " because it is already marked.");
        end;
      end;
    end;
  end;

  if (want_remove_water) then
    diag(5, actor_entity_desc ..
            ": Scanning area within " .. obstacle_tile_radius ..
            " units of " .. pos_str(actor_entity.position) ..
            " for obstacle tiles.");

    area = bounding_box_with_radius(actor_entity.position, obstacle_tile_radius);

    local tiles = surface.find_tiles_filtered{
      area = area,
      name = landfillable_tile_names,
      has_tile_ghost = false,
      force = force,
    };
    for _, tile in pairs(tiles) do
      diag(3, "Ordering landfill of " .. tile.name ..
              " tile at " .. pos_str(tile.position) .. ".");

      surface.create_entity{
        name = "tile-ghost",
        expires = false,
        force = force,
        position = tile.position,
        inner_name = "landfill",
        raise_built = true,
      };
    end;
  end;
end;


-- True if `player` has moved within the past `action_period_ticks`,
-- given that it is `cur_tick`.  `action` is a string describing what
-- we do periodically.
local function player_moved_recently(
  player,
  cur_tick,
  action_period_ticks,
  action)

  local moved_tick = player_index_to_last_move_tick[player.index];
  if (moved_tick == nil) then
    --[[
    diag(5, "Player " .. player.index ..
            " has not moved since the mod was loaded, skipping " ..
            action .. ".");
    --]]
    return false;
  end;

  local ticks_since_moved = cur_tick - moved_tick;
  if (ticks_since_moved > action_period_ticks) then
    -- Normally commented-out since this is the usual case and the
    -- whole point is optimization.
    --[[
    diag(5, "Player " .. player.index ..
            " last moved on tick " .. moved_tick ..
            ", but it is now tick " .. cur_tick ..
            ", which is " .. ticks_since_moved .. " elapsed ticks, " ..
            "which is greater than the current " .. action ..
            " period of " .. action_period_ticks ..
            ", so skipping this player.");
    --]]
    return false;
  end;

  return true;
end;


-- True if `player` meets all the requirements for the bulldozer to
-- function.
local function player_bulldozer_enabled(player)
  if (not settings.get_player_settings(player.index)["bulldozer-equipment-enable-for-player"].value) then
    diag(5, "Player " .. player.index .. " has disabled the mod.");
    return false;
  end;

  if (player.character == nil) then
    diag(5, "Player " .. player.index .. " has no character.");
    return false;
  end;

  return entity_has_bulldozer(player.character);
end;


-- Scan near one player.
local function player_check_for_obstacles(player, cur_tick)
  if (not player_moved_recently(player, cur_tick,
                                obstacle_check_period_ticks,
                                "obstacle check")) then
    return false;
  end;

  if (not player_bulldozer_enabled(player)) then
    return;
  end;

  entity_check_for_obstacles(player.character);
end;


-- Scan the areas near all players.
local function all_players_check_for_obstacles(tick)
  for _, player in pairs(game.players) do
    player_check_for_obstacles(player, tick);
  end;
end;


-- Scan near one vehicle.
local function vehicle_check_for_obstacles(vehicle)
  entity_check_for_obstacles(vehicle);
end;


-- Scan the areas near all moving vehicles.
local function all_vehicles_check_for_obstacles()
  for _, vehicle in pairs(game.get_vehicles{is_moving=true}) do
    vehicle_check_for_obstacles(vehicle);
  end;
end;


-- Description of what we insert when we successfully convert items to
-- landfill.
local one_item_landfill_stack = {
  name = "landfill",
  count = 1,
};


-- Try to create landfill by converting `num_input_items_required` of
-- `input_item_name` to one landfill item.  Return true if we were able
-- to convert and insert.
local function create_landfill_from_item(
  situation,                 -- string: What we are doing.
  source_inv,                -- LuaInventory to take from.
  dest_inv,                  -- LuaInventory to insert into
  input_item_name,           -- string: The name of the item to convert.
  num_input_items_required   -- int: Number of items to convert.
)
  local num_input_items = source_inv.get_item_count(input_item_name);
  if (num_input_items >= num_input_items_required) then
    local num_removed = source_inv.remove{
      name = input_item_name,
      count = num_input_items_required,
    };
    if (num_removed ~= num_input_items_required) then
      diag(1, situation ..
              ": The attempt to remove " .. num_input_items_required ..
              " " .. input_item_name ..
              "failed!  The actual number removed was " .. num_removed ..
              ".  The removed items will simply be lost.");
      return false;
    end;

    local num_inserted = dest_inv.insert(one_item_landfill_stack);
    if (num_inserted ~= 1) then
      diag(1, situation .. ": The attempt to insert one landfill failed!  " ..
              "The actual number inserted was " .. num_inserted ..
              ".  The removed items will simply be lost.");
      return false;
    end;

    diag(3, situation .. ": Successfully removed " ..
            num_input_items_required .. " " .. input_item_name ..
            " and inserted one landfill.");
    return true;

  elseif (num_input_items > 0) then
    diag(5, situation .. ": The inventory contains " .. num_input_items ..
            " " .. input_item_name ..
            ", but that is less than the required " .. num_input_items_required ..
            ", so they will be ignored.");
    return false;

  end;

  -- No items of the indicated kind.
  return false;
end;


-- Try to create a landfill item by taking items from `source_inv`.  Put
-- the resulting item into `dest_inv`.  Return true if one landfill item
-- was successfully converted.
local function create_landfill(situation, source_inv, dest_inv)
  if (not dest_inv.can_insert(one_item_landfill_stack)) then
    diag(2, situation .. ": No space in destination inventory.");
    return false;
  end;

  if (create_landfill_from_item(situation, source_inv, dest_inv,
                                "stone", 50)) then
    return true;
  end;

  if (create_landfill_from_item(situation, source_inv, dest_inv,
                                "wood", 100)) then
    return true;
  end;

  if (create_landfill_from_item(situation, source_inv, dest_inv,
                                "coal", 50)) then
    return true;
  end;

  diag(5, situation .. ": No items to convert to landfill.");
  return false;
end;


-- Possibly create landfill for one entity.
local function entity_create_landfill(
  entity,
  main_inv_id,
  trash_inv_id
)
  local entity_desc = entity.name .. " " .. entity.unit_number;

  local main_inv = entity.get_inventory(main_inv_id);
  if (not main_inv) then
    diag(4, entity_desc .. " does not have a main inventory.");
    return;
  end;

  -- Try converting from trash first.
  local trash_inv = entity.get_inventory(trash_inv_id);
  if (not trash_inv) then
    diag(4, entity_desc .. " does not have a trash inventory.");
  else
    local situation =
      entity_desc .. " creating landfill from trash inventory";
    if (create_landfill(situation, trash_inv, main_inv)) then
      return;
    end;
  end;

  -- Then convert from the main inventory.
  local situation =
    entity_desc .. " creating landfill from main inventory";
  if (create_landfill(situation, main_inv, main_inv)) then
    return;
  end;
end;


-- Possibly create landfill for one player.
local function player_create_landfill(player)
  -- Among other things, ensure the player has a character.
  if (not player_bulldozer_enabled(player)) then
    return;
  end;

  entity_create_landfill(player.character,
    defines.inventory.character_main,
    defines.inventory.character_trash);
end;


-- Possibly create landfill for all players.
local function all_players_create_landfill()
  for _, player in pairs(game.players) do
    player_create_landfill(player);
  end;
end;


-- Possibly create landfill for one vehicle.
local function vehicle_create_landfill(vehicle)
  if (not entity_has_bulldozer(vehicle)) then
    return;
  end;

  -- Note: There is no inventory define for `car_trash`, but it appears
  -- that the tank at least follows the same pattern of values as the
  -- spider, so we can use `spider_trash` (which has value 4) to get the
  -- tank trash inventory.
  --
  -- Submitted a feature request to add `car_trash`:
  -- https://forums.factorio.com/viewtopic.php?f=6&t=124950
  --
  entity_create_landfill(vehicle,
    defines.inventory.car_trunk,
    defines.inventory.spider_trash);
end;


-- Possibly create landfill for all vehicles that are moving.
local function all_vehicles_create_landfill()
  for _, vehicle in pairs(game.get_vehicles{is_moving=true}) do
    vehicle_create_landfill(vehicle);
  end;
end;


-- Called for the obstacle check tick handler.
local function on_obstacle_check_tick(event)
  all_players_check_for_obstacles(event.tick);
  all_vehicles_check_for_obstacles();
end;


-- Called for the landfill creation tick handler.
local function on_landfill_creation_tick(event)
  all_players_create_landfill();
  all_vehicles_create_landfill();
end;


-- If `period_ticks` is non-zero, register `handler`.
local function possibly_register_nth_tick_handler(period_ticks, action, handler)
  if (period_ticks == 0) then
    diag(4, "Tick handler for " .. action .. " is disabled.");

  else
    diag(4, "Tick handler for " .. action ..
            " is set to run every " .. period_ticks ..
            " ticks.");
    script.on_nth_tick(period_ticks, handler);

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

  diagnostic_verbosity           = settings.global["bulldozer-equipment-diagnostic-verbosity"].value;
  obstacle_check_period_ticks    = settings.global["bulldozer-equipment-obstacle-check-period-ticks"].value;
  landfill_creation_period_ticks = settings.global["bulldozer-equipment-landfill-creation-period-ticks"].value;
  obstacle_entity_radius         = settings.global["bulldozer-equipment-obstacle-entity-radius"].value;
  obstacle_tile_radius           = settings.global["bulldozer-equipment-obstacle-tile-radius"].value;
  want_remove_trees              = settings.global["bulldozer-equipment-want-remove-trees"].value;
  want_remove_rocks              = settings.global["bulldozer-equipment-want-remove-rocks"].value;
  want_remove_cliffs             = settings.global["bulldozer-equipment-want-remove-cliffs"].value;
  want_remove_water              = settings.global["bulldozer-equipment-want-remove-water"].value;

  -- Re-establish the tick handlers with the new periods.
  if (obstacle_check_period_ticks == landfill_creation_period_ticks) then
    possibly_register_nth_tick_handler(obstacle_check_period_ticks,
      "both",
      function(e)
        on_obstacle_check_tick(e);
        on_landfill_creation_tick(e);
      end);

  else
    possibly_register_nth_tick_handler(obstacle_check_period_ticks,
      "obstacle check",
      on_obstacle_check_tick);

    possibly_register_nth_tick_handler(landfill_creation_period_ticks,
      "landfill creation",
      on_landfill_creation_tick);

  end;

  diag(4, "read_configuration_settings end");
end;


-- Called when a player moves.
local function on_player_changed_position(e)
  --diag(5, "Player " .. e.player_index ..
  --        " moved on tick " .. e.tick .. ".");
  player_index_to_last_move_tick[e.player_index] = e.tick;
end;


-- Set `landfillable_tile_names`.
--
-- I would prefer to just read
-- `data.raw.item.landfill.place_as_tile.tile_condition`, but that
-- information does not seem to be available in the control stage, and
-- there is no mechanism for passing information from the data stage.
--
-- So, instead, I query each element of a hardcoded list of tiles, and
-- add those that are found to exist.  (`find_tiles_filtered` will
-- throw an error if I pass the name of a tile that does not exist.)
--
local function set_landfillable_tile_names()
  -- These are the landfillable tiles in the base game and Space Age.
  local candidates = {
    "water",
    "deepwater",
    "water-green",
    "deepwater-green",
    "water-mud",
    "water-shallow",
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
  };

  landfillable_tile_names = {};
  for _, candidate in pairs(candidates) do
    if (prototypes.tile[candidate] ~= nil) then
      diag(4, "Landfillable tile: " .. candidate);
      table.insert(landfillable_tile_names, candidate);
    end;
  end;
end;


local function on_runtime_mod_setting_changed(event)
  read_configuration_settings();
end;


-- -------------------------- Initialization ---------------------------
read_configuration_settings();

script.on_event(defines.events.on_runtime_mod_setting_changed,
  on_runtime_mod_setting_changed);

script.on_event(defines.events.on_player_changed_position,
  on_player_changed_position);

set_landfillable_tile_names();


-- EOF
