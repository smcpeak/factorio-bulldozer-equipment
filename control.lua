-- control.lua


-- ------------------------ Configuration data -------------------------
-- The default values in this section are overwritten when the user
-- settings are read, but for convenience, these values are the same
-- as the default setting values.

-- If true, call the `error` function when something goes wrong, causing
-- a crash.
local call_error_on_bug = false;

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

-- Map from player_index to that player's preferences, which is a table
-- containing:
--[[
  -- True if the mod is generally enabled.
  bool enabled = true;

  -- Maximum distance to a "nearby" obstacle entity, in game grid units.
  int obstacle_entity_radius = 16;

  -- Maximum distance to a "nearby" obstacle tile, in game grid units.
  --
  -- This is different from the entity radius because, in playtesting, the
  -- larger radius seems excessive and obnoxious for tiles, while the
  -- smaller radius is not big enough for rocks and trees.  In part, that
  -- relates to the much bigger investment in time and resources required
  -- to clear obstacle tiles versus obstacle entities.
  --
  int obstacle_tile_radius = 8;

  -- Whether to clear each specific obstacle.
  bool want_remove_trees = true;
  bool want_remove_rocks = true;
  bool want_remove_cliffs = true;
  bool want_remove_water = true;

  -- Whether to create landfill, and from what.
  bool want_landfill_from_wood = true;
  bool want_landfill_from_coal = true;
  bool want_landfill_from_stone = true;
--]]
local player_index_to_prefs = {};


-- --------------------------- Runtime data ----------------------------
-- List of names of tiles we can landfill.  Set below, during
-- initialization.
local landfillable_tile_names = {};

-- For each player, the most recent tick on which they moved.
local player_index_to_last_move_tick = {};

-- Map from unit number to a LuaEntity whose equipment grid contains the
-- bulldozer equipment installed.  This is nil until we do an initial
-- scan.  All entities are either cars or characters.
--
-- TODO: Allow other kinds of vehicles too?  A concern is the
-- applicability of the optimization that checks the speed.
--
local unit_number_to_equipped_entity = nil;


-- ----------------------- Forward declarations ------------------------
local get_player_index_prefs;


-- ------------------------- Utility functions -------------------------
-- Log 'str' if we are at verbosity 'v' or higher.
local function diag(v, str)
  if (v <= diagnostic_verbosity) then
    log(str);
  end;
end;


-- Called when we have encountered a condition that indicates this mod
-- has a bug.
local function report_bug(message)
  diag(1, "BUG: " .. message);

  if (call_error_on_bug) then
    error(message);
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


-- Return a string succinctly describing this entity.
local function entity_desc(entity)
  -- Since this is used as part of the diagnostics, be extra defensive
  -- here so I don't lose info about unexpected circumstances.
  if (entity.valid) then
    if (entity.unit_number) then
      return entity.name .. " " .. entity.unit_number;
    else
      return entity.name .. " with no unit number";
    end;
  else
    return "<invalid entity>";
  end;
end;


-- Get the player index associated with entity 'e', or -1 if this
-- entity is not associated with a player.
local function player_index_of_entity(e)
  if (e.type == 'car') then
    -- Vehicle.
    --
    -- Normally vehicles always have a last_user, but with mods it is
    -- evidently possible for last_user to be nil:
    -- https://mods.factorio.com/mod/RoboTank/discussion/5cb114b4a07570000cfc3762
    if (e.last_user == nil) then
      return -1;
    else
      return e.last_user.index;
    end;
  elseif (e.type == 'character') then
    -- Character.
    if (e.player ~= nil) then
      return e.player.index;
    else
      return -1;
    end;
  else
    return -1;
  end;
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


-- ------------------------- Equipment checks --------------------------
-- If `entity` is associated with a player that has not disabled the
-- mod, return that player's preferences.  Otherwise return nil and log
-- the reason for it not being available.
local function entity_bulldozer_prefs(entity)
  local player_index = player_index_of_entity(entity);
  if (player_index < 0) then
    diag(4, entity_desc(entity) .. " is not associated with a player.");
    return nil;
  end;

  local prefs = get_player_index_prefs(player_index);
  if (not prefs.enabled) then
    if (diagnostic_verbosity >= 5) then
      diag(5, entity_desc(entity) .. " has the mod disabled.");
    end;
    return nil;
  end;

  return prefs;
end;


-- If `entity` has the bulldozer equipment, return it as a LuaEquipment,
-- ignoring whether it has sufficient power to operate.  Otherwise
-- return nil and log the reason..
local function get_equipped_bulldozer(entity)
  local equipment_grid = entity.grid;
  if (equipment_grid == nil) then
    diag(5, entity_desc(entity) .. " has no equipment grid.");
    return nil;
  end;

  local bulldozer_equipment = equipment_grid.find("bulldozer-equipment");
  if (bulldozer_equipment == nil) then
    diag(5, entity_desc(entity) .. " does not have a bulldozer.");
    return nil;
  end;

  return bulldozer_equipment;
end;


-- If `entity` meets all the requirements to have a functioning
-- bulldozer, return the preferences associated with its player.
-- Otherwise return nil and log the reason.
local function entity_powered_enabled_bulldozer_prefs(entity)
  local prefs = entity_bulldozer_prefs(entity);
  if (not prefs) then
    -- Reason has been logged.
    return nil;
  end;

  local bulldozer_equipment = get_equipped_bulldozer(entity);
  if (bulldozer_equipment == nil) then
    -- Reason has been logged.
    return nil;
  end;

  local required_energy = bulldozer_equipment.max_energy / 2;
  if (bulldozer_equipment.energy < required_energy) then
    diag(3, entity_desc(entity) ..
            " has a bulldozer with " .. bulldozer_equipment.energy ..
            " J, but that is less than the required " .. required_energy ..
            " J, so it is not operational.");
    return nil;
  end;

  return prefs;
end;


-- If `entity` has the bulldozer equipment, add it to
-- `unit_number_to_equipped_entity`.
local function possibly_record_equipped_entity(entity)
  if (get_equipped_bulldozer(entity)) then
    diag(4, entity_desc(entity) .. " has the bulldozer equipped.");
    unit_number_to_equipped_entity[entity.unit_number] = entity;
  end;
end;


-- Scan the world for entities that have the bulldozer equipment, and
-- record them in `unit_number_to_equipped_entity`.
local function refresh_unit_number_to_equipped_entity()
  diag(4, "Refreshing unit_number_to_equipped_entity.");
  unit_number_to_equipped_entity = {};

  for _, player in pairs(game.players) do
    if (player.character) then
      possibly_record_equipped_entity(player.character);
    end;
  end;

  for _, vehicle in pairs(game.get_vehicles{}) do
    possibly_record_equipped_entity(vehicle);
  end;
end;


-- Refresh the table of entities if we just started running.
local function maybe_initialize_unit_number_to_equipped_entity()
  if (not unit_number_to_equipped_entity) then
    refresh_unit_number_to_equipped_entity();
  end;
end;


-- Clear the table entry associated with `entity` and query its grid
-- again.
local function refresh_whether_entity_is_equipped(entity)
  if (entity.unit_number) then
    unit_number_to_equipped_entity[entity.unit_number] = nil;
    possibly_record_equipped_entity(entity);
  else
    report_bug("Refreshing an entity with no unit number.");
  end;
end;


-- Called when equipment is added to or removed from a grid.
local function on_equipment_inserted_or_removed(event)
  local inserted = (event.name == defines.events.on_equipment_inserted);
  local change_desc = (inserted and "inserted" or "removed");

  -- The insertion event passes a LuaEquipment, while the removal event
  -- only passes a string, because once something is removed from the
  -- grid, it ceases to be a LuaEquipment.
  --
  -- Another difference is that insertion of multiple items causes
  -- multiple events, while removal of multiple items only causes one
  -- event.
  --
  local equipment_name =
    (inserted and
      event.equipment.name or
      event.equipment);

  diag(5, "on_equipment_inserted_or_removed:" ..
          " inserted=" .. tostring(inserted) ..
          " name=" .. equipment_name);

  if (equipment_name == "bulldozer-equipment") then
    local entity = event.grid.entity_owner;
    if (entity == nil) then
      -- Seems like this could only happen in a multiplayer scenario,
      -- and maybe not even then.  Or maybe this could happen if a mod
      -- can reach into the equipment grid of a vehicle that has been
      -- picked up, and is hence an item rather than an entity?
      diag(3, "Bulldozer " .. change_desc .. " but the entity is nil.");
      return;
    end;

    diag(3, "Bulldozer equipment " .. change_desc ..
            " for " .. entity_desc(entity) .. ".");

    if (entity.type ~= "car" and entity.type ~= "character") then
      diag(3, "But it is neither a car nor a character.");
      return;
    end;

    -- In the insertion case, we know the equipment is there now.  But
    -- in the removal case, there could still be another one present.
    refresh_whether_entity_is_equipped(entity);
  end;
end;


-- ------------------------ Clearing obstacles -------------------------
-- Scan near one entity for natural obstacles if it has the necessary
-- equipment.
local function entity_check_for_obstacles(actor_entity, prefs)
  local force = actor_entity.force;
  local surface = actor_entity.surface;

  local include_cliffs =
    prefs.want_remove_cliffs and
    force.cliff_deconstruction_enabled;

  if (prefs.want_remove_trees or
      prefs.want_remove_rocks or
      include_cliffs) then
    local types = {};
    if (prefs.want_remove_trees) then
      table.insert(types, "tree");
    end;
    if (prefs.want_remove_rocks) then
      table.insert(types, "simple-entity");
    end;
    if (include_cliffs) then
      table.insert(types, "cliff");
    end;

    if (diagnostic_verbosity >= 5) then
      diag(5, entity_desc(actor_entity) ..
              ": Scanning area within " .. prefs.obstacle_entity_radius ..
              " units of " .. pos_str(actor_entity.position) ..
              " for obstacle entities: " .. serpent.line(types));
    end;

    local area = bounding_box_with_radius(
      actor_entity.position,
      prefs.obstacle_entity_radius);

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

  if (prefs.want_remove_water) then
    if (diagnostic_verbosity >= 5) then
      diag(5, entity_desc(actor_entity) ..
              ": Scanning area within " .. prefs.obstacle_tile_radius ..
              " units of " .. pos_str(actor_entity.position) ..
              " for obstacle tiles.");
    end;

    area = bounding_box_with_radius(
      actor_entity.position,
      prefs.obstacle_tile_radius);

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
-- given that it is `cur_tick`.
local function player_moved_recently(
  player,
  cur_tick,
  action_period_ticks
)
  local moved_tick = player_index_to_last_move_tick[player.index];
  if (moved_tick == nil) then
    if (diagnostic_verbosity >= 5) then
      diag(5, "Player " .. player.index .. " is not moving.");
    end;
    return false;
  end;

  local ticks_since_moved = cur_tick - moved_tick;
  if (ticks_since_moved > action_period_ticks) then
    if (diagnostic_verbosity >= 5) then
      diag(5, "Player " .. player.index .. " is not moving.");
    end;
    return false;
  end;

  return true;
end;


-- Called when a player moves.
local function on_player_changed_position(e)
  if (diagnostic_verbosity >= 5) then
    diag(5, "Player " .. e.player_index ..
            " moved on tick " .. e.tick .. ".");
  end;
  player_index_to_last_move_tick[e.player_index] = e.tick;
end;


-- Scan near one player.
local function player_check_for_obstacles(player, prefs, cur_tick)
  if (not player_moved_recently(player, cur_tick,
                                obstacle_check_period_ticks)) then
    return false;
  end;

  entity_check_for_obstacles(player.character, prefs);
end;


-- Scan near one vehicle.
local function vehicle_check_for_obstacles(vehicle, prefs)
  entity_check_for_obstacles(vehicle, prefs);
end;


-- Do something for all equipped and enabled entities, depending on its
-- type.  For character entities, we pass the associated player, or do
-- nothing if there isn't one.  In both cases, the second argument is
-- the applicable preferences.
local function for_all_powered_enabled_equipped_entities(
  action_desc,
  vehicle_action,
  player_action
)
  maybe_initialize_unit_number_to_equipped_entity();

  if (diagnostic_verbosity >= 5) then
    diag(5, "---- all enabled equipped entities: " .. action_desc .. " ----");
  end;

  for unit_number, entity in pairs(unit_number_to_equipped_entity) do
    if (not entity.valid) then
      -- I'm supposed to be listening to events to ensure this does not
      -- happen.
      report_bug("Found invalid unit " .. unit_number .. " in the table!");
      unit_number_to_equipped_entity[unit_number] = nil;

    else
      if (diagnostic_verbosity >= 5) then
        diag(5, "Considering entity " .. entity_desc(entity));
      end;

      if (entity.type == "car") then
        -- As an optimization, only do things with a moving vehicle.
        if (entity.speed == 0) then
          if (diagnostic_verbosity >= 5) then
            diag(5, entity_desc(entity) .. " is not moving.");
          end;

        else
          local prefs = entity_powered_enabled_bulldozer_prefs(entity);
          if (prefs) then
            vehicle_action(entity, prefs);
          end;

        end;

      elseif (entity.type == "character") then
        if (entity.player) then
          local prefs = entity_powered_enabled_bulldozer_prefs(entity);
          if (prefs) then
            player_action(entity.player, prefs);
          end;

        else
          if (diagnostic_verbosity >= 5) then
            diag(5, entity_desc(entity) .. " is a character that is " ..
                    "not associated with any player.");
          end;

        end;

      else
        report_bug(entity_desc(entity) .. " is neither a car nor " ..
                   "a character; how did it get into my table?");

      end;
    end;
  end;
end;


-- Scan the areas near all equipped entities for obstacles to clear.
local function all_equipped_entities_check_for_obstacles(cur_tick)
  for_all_powered_enabled_equipped_entities(
    "check for obstacles",
    vehicle_check_for_obstacles,
    function(player, prefs)
      player_check_for_obstacles(player, prefs, cur_tick);
    end
  );
end;


-- Called for the obstacle check tick handler.
local function on_obstacle_check_tick(event)
  all_equipped_entities_check_for_obstacles(event.tick);
end;


-- ------------------------- Landfill creation -------------------------
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
local function create_landfill(situation, source_inv, dest_inv, prefs)
  if (not dest_inv.can_insert(one_item_landfill_stack)) then
    diag(2, situation .. ": No space in destination inventory.");
    return false;
  end;

  if (prefs.want_landfill_from_stone and
      create_landfill_from_item(situation, source_inv, dest_inv,
                                "stone", 50)) then
    return true;
  end;

  if (prefs.want_landfill_from_wood and
      create_landfill_from_item(situation, source_inv, dest_inv,
                                "wood", 100)) then
    return true;
  end;

  if (prefs.want_landfill_from_coal and
      create_landfill_from_item(situation, source_inv, dest_inv,
                                "coal", 50)) then
    return true;
  end;

  diag(5, situation .. ": No items to convert to landfill.");
  return false;
end;


-- True if at least one landfill creation option is enabled.
local function want_some_landfill(prefs)
  return prefs.want_landfill_from_wood or
         prefs.want_landfill_from_coal or
         prefs.want_landfill_from_stone;
end;


-- Possibly create landfill for one entity.
local function entity_create_landfill(
  entity,
  prefs,
  main_inv_id,
  trash_inv_id
)
  if (not want_some_landfill(prefs)) then
    diag(5, entity_desc(entity) .. " has landfill creation disabled.");
    return;
  end;

  local main_inv = entity.get_inventory(main_inv_id);
  if (not main_inv) then
    diag(4, entity_desc(entity) .. " does not have a main inventory.");
    return;
  end;

  -- Try converting from trash first.
  local trash_inv = entity.get_inventory(trash_inv_id);
  if (not trash_inv) then
    diag(4, entity_desc(entity) .. " does not have a trash inventory.");
  else
    local situation =
      entity_desc(entity) .. " creating landfill from trash inventory";
    if (create_landfill(situation, trash_inv, main_inv, prefs)) then
      return;
    end;
  end;

  -- Then convert from the main inventory.
  local situation =
    entity_desc(entity) .. " creating landfill from main inventory";
  if (create_landfill(situation, main_inv, main_inv, prefs)) then
    return;
  end;
end;


-- Possibly create landfill for one player.
local function player_create_landfill(player, prefs)
  entity_create_landfill(player.character,
    prefs,
    defines.inventory.character_main,
    defines.inventory.character_trash);
end;


-- Possibly create landfill for one vehicle.
local function vehicle_create_landfill(vehicle, prefs)
  -- Note: There is no inventory define for `car_trash`, but it appears
  -- that the tank at least follows the same pattern of values as the
  -- spider, so we can use `spider_trash` (which has value 4) to get the
  -- tank trash inventory.
  --
  -- Submitted a feature request to add `car_trash`:
  -- https://forums.factorio.com/viewtopic.php?f=6&t=124950
  --
  entity_create_landfill(vehicle,
    prefs,
    defines.inventory.car_trunk,
    defines.inventory.spider_trash);
end;


-- For all bulldozer-equipped entities, possibly create landfill.
local function all_equipped_entities_create_landfill()
  for_all_powered_enabled_equipped_entities(
    "create landfill",
    vehicle_create_landfill,
    player_create_landfill);
end;


-- Called for the landfill creation tick handler.
local function on_landfill_creation_tick(event)
  all_equipped_entities_create_landfill();
end;


-- -------------------------- Shortcut button --------------------------
-- Set the state of the shortcut button based on the current settings.
local function set_one_player_shortcut_button_state(player)
  local setting_name = "bulldozer-equipment-enable-for-player";
  local shortcut_name = "bulldozer-equipment";

  local player_settings = settings.get_player_settings(player.index);
  local cur_value = player_settings[setting_name].value;

  -- Here, "toggled" means "pressed", i.e., enabled.
  player.set_shortcut_toggled(shortcut_name, cur_value);

  diag(3, "Player " .. player.index ..
          ": Set shortcut button state to " .. tostring(cur_value));

end;


-- For all players, set their shortcut button state.
local function set_all_players_shortcut_button_state()
  for _, player in (pairs(game.players)) do
    set_one_player_shortcut_button_state(player);
  end;
end


-- Toggle the enablement for `player_index`.
local function toggle_bulldozer_for_player(player_index)
  local setting_name = "bulldozer-equipment-enable-for-player";

  -- Toggle the settings value.  This sends mod_setting_changed
  -- event, which will update the shortcut button in the UI.
  local player_settings = settings.get_player_settings(player_index);
  local new_value = not player_settings[setting_name].value;
  player_settings[setting_name] = {value = new_value};
end;


-- React to pressing the shortcut button.
local function on_shortcut_pressed(event)
  if (event.prototype_name == "bulldozer-equipment") then
    diag(4, "on_shortcut_pressed: " .. serpent.block(event));

    toggle_bulldozer_for_player(event.player_index);
  end;
end;


-- Called when the bulldozer custom input key is pressed.
local function on_custom_input(event)
  diag(4, "on_custom_input: " .. serpent.block(event));

  toggle_bulldozer_for_player(event.player_index);
end;


-- ------------------------- Entity lifecycle --------------------------
-- Filter for entity lifecycle events.
local entity_event_filter = {
  {
    filter = "type",
    type = "character",
  },
  {
    filter = "type",
    type = "car",
    mode = "or",
  },
};


-- Called when an entity is built, either by the player or a robot.
local function on_player_or_robot_built_entity(event)
  local entity = event.entity;

  diag(4, entity_desc(entity) .. " built.");

  possibly_record_equipped_entity(entity);
end;

script.on_event(
  defines.events.on_built_entity,
  on_player_or_robot_built_entity,
  entity_event_filter);

script.on_event(
  defines.events.on_robot_built_entity,
  on_player_or_robot_built_entity,
  entity_event_filter);


-- Called when an entity is mined (picked up) by a player or robot.
local function on_player_or_robot_mined_entity(event)
  local entity = event.entity;

  diag(4, entity_desc(entity) .. " mined.");

  if (entity.unit_number) then
    unit_number_to_equipped_entity[entity.unit_number] = nil;
  else
    report_bug("Saw an entity die with no unit number.");
  end;
end;

script.on_event(
  defines.events.on_player_mined_entity,
  on_player_or_robot_mined_entity,
  entity_event_filter);

script.on_event(
  defines.events.on_robot_mined_entity,
  on_player_or_robot_mined_entity,
  entity_event_filter);


-- Called when an entity dies.
local function on_entity_died(event)
  local entity = event.entity;

  diag(4, entity_desc(entity) .. " died.");

  if (entity.unit_number) then
    unit_number_to_equipped_entity[entity.unit_number] = nil;
  else
    -- This happened during development when I typo'd the name of the
    -- event filter table, thus disabling it.  Hopefully that is now
    -- fixed and this will not happen.
    report_bug("Saw an entity die with no unit number.");
  end;
end;

script.on_event(
  defines.events.on_entity_died,
  on_entity_died,
  entity_event_filter);


-- Map from a numeric player-change event name to its string name.
local player_event_name_string = {
  [defines.events.on_player_created                ] = "created"      ,
  [defines.events.on_player_died                   ] = "died"         ,
  [defines.events.on_player_joined_game            ] = "joined game"  ,
  [defines.events.on_player_left_game              ] = "left game"    ,
  [defines.events.on_player_removed                ] = "removed"      ,
  [defines.events.on_player_respawned              ] = "respawned"    ,

  -- Called when the player's armor changes.  I think the word
  -- "inventory" refers to the fact that the slot where the armor goes
  -- is considered to be an inventory slot.
  [defines.events.on_player_armor_inventory_changed] = "changed armor",
};

-- Called when a player is added to or removed from the game.
local function on_player_changed(event)
  local player_index = event.player_index;

  local event_name_string = player_event_name_string[event.name];
  if (not event_name_string) then
    event_name_string = "(unknown event " .. event.name .. ")";
  end;

  diag(4, "Player " .. player_index .. " " .. event_name_string);

  local player = game.get_player(player_index);
  local character = player.character;

  -- I doubt I need to check validity here, but just in case...
  if (character and character.valid) then
    diag(4, "Player character is " .. entity_desc(character) .. ".");

    refresh_whether_entity_is_equipped(character);
  end;
end;

for event_id, _ in pairs(player_event_name_string) do
  script.on_event(event_id, on_player_changed);
end;


-- --------------------------- Configuration ---------------------------
-- Return a table containing the preferences for `player_index`.
get_player_index_prefs = function(player_index)
  local ret = player_index_to_prefs[player_index];
  if (ret) then
    return ret;
  end;

  -- Must re-read from the API.  The docs imply this cannot return nil.
  local player_settings = settings.get_player_settings(player_index);
  ret = {
    enabled                  = player_settings["bulldozer-equipment-enable-for-player"].value,
    obstacle_entity_radius   = player_settings["bulldozer-equipment-obstacle-entity-radius"].value,
    obstacle_tile_radius     = player_settings["bulldozer-equipment-obstacle-tile-radius"].value,
    want_remove_trees        = player_settings["bulldozer-equipment-want-remove-trees"].value,
    want_remove_rocks        = player_settings["bulldozer-equipment-want-remove-rocks"].value,
    want_remove_cliffs       = player_settings["bulldozer-equipment-want-remove-cliffs"].value,
    want_remove_water        = player_settings["bulldozer-equipment-want-remove-water"].value,
    want_landfill_from_wood  = player_settings["bulldozer-equipment-want-landfill-from-wood"].value,
    want_landfill_from_coal  = player_settings["bulldozer-equipment-want-landfill-from-coal"].value,
    want_landfill_from_stone = player_settings["bulldozer-equipment-want-landfill-from-stone"].value,
  };
  diag(4, "Player " .. player_index ..
          " has settings: " .. serpent.line(ret));

  player_index_to_prefs[player_index] = ret;
  return ret;
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

  -- Update global preferences.
  call_error_on_bug              = settings.global["bulldozer-equipment-call-error-on-bug"].value;
  diagnostic_verbosity           = settings.global["bulldozer-equipment-diagnostic-verbosity"].value;
  obstacle_check_period_ticks    = settings.global["bulldozer-equipment-obstacle-check-period-ticks"].value;
  landfill_creation_period_ticks = settings.global["bulldozer-equipment-landfill-creation-period-ticks"].value;

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

  -- Force per-player settings to be refreshed on demand.
  player_index_to_prefs = {};

  diag(4, "read_configuration_settings end");
end;


local function on_runtime_mod_setting_changed(event)
  diag(4, "runtime_mod_setting_changed:" ..
          " setting=" .. event.setting ..
          " setting_type=" .. event.setting_type ..
          " player_index=" .. tostring(event.player_index));

  read_configuration_settings();

  if (event.setting == "bulldozer-equipment-enable-for-player") then
    -- Update shortcut button state.
    set_one_player_shortcut_button_state(game.get_player(event.player_index));
  end;
end;


-- Called when the game has been update, mods added, etc.
local function on_configuration_changed(event)
  diag(4, "on_configuration_changed: " .. serpent.block(event));

  -- I don't have anything to do here, but I want to log the event for
  -- my own edification.
end;


-- Called when this mod is added to a save.
local function on_init()
  diag(4, "on_init");

  -- This is how we get the shortcut button to start in the "toggled"
  -- (pressed) state.  The button state is then persisted in the save
  -- file, so nothing more needs to be done when loading a save where
  -- the mod was already present.
  set_all_players_shortcut_button_state();
end;


-- -------------------------- Initialization ---------------------------
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


read_configuration_settings();

script.on_event(defines.events.on_runtime_mod_setting_changed,
  on_runtime_mod_setting_changed);

script.on_event(defines.events.on_player_changed_position,
  on_player_changed_position);

script.on_event({defines.events.on_equipment_inserted,
                 defines.events.on_equipment_removed},
  on_equipment_inserted_or_removed);

script.on_event(defines.events.on_lua_shortcut,
  on_shortcut_pressed);

script.on_event("toggle-bulldozer-equipment",
  on_custom_input);

script.on_configuration_changed(on_configuration_changed);

script.on_init(on_init);

set_landfillable_tile_names();


-- EOF
