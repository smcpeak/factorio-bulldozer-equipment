-- data.lua

local mod_name = "__BulldozerModule__";


-- ----------------------------- Equipment -----------------------------
-- Unfortunately, there is not a generic category of equipment.
-- Instead, one must extend one of the types in the base game.  I'm
-- following the lead of the "Extended Vanilla: Personal Equipment" mod,
-- which extends the belt immunity device.
local bulldozer_equipment = table.deepcopy(
  data.raw["belt-immunity-equipment"]["belt-immunity-equipment"]);

bulldozer_equipment.name = "bulldozer-equipment";

bulldozer_equipment.sprite = {
  filename = mod_name .. "/graphics/equipment/bulldozer.png",
  width = 64,
  height = 64,
  priority = "medium",
};

-- Twice the draw of ordinary belt immunity, since it (unavoidably) has
-- that function as well.
bulldozer_equipment.energy_consumption = "200kW";

bulldozer_equipment.energy_source = {
  buffer_capacity = "200kJ",
  input_flow_limit = "240kW",
  type = "electric",
  usage_priority = "primary-input"
};

bulldozer_equipment.order = "b-i-b";


-- ------------------------------- Item --------------------------------
local bulldozer_item = table.deepcopy(data.raw.item["belt-immunity-equipment"]);
bulldozer_item.name                      = "bulldozer-equipment";
bulldozer_item.icon                      = mod_name .. "/graphics/icons/bulldozer.png";
bulldozer_item.order                     = "c[belt-immunity]-a[bulldozer]";
bulldozer_item.place_as_equipment_result = "bulldozer-equipment";


-- ------------------------------ Recipe -------------------------------
local bulldozer_recipe = {
  name = "bulldozer-equipment",
  type = "recipe",

  enabled = true,             -- TODO: Unlock with research.
  energy_required = 10,       -- 10s to craft, like other equipment.

  ingredients = {
    -- A radar to scan for nearby obstacles.
    {
      amount = 1,
      name = "radar",
      type = "item",
    },

    -- A computer to process the results.
    {
      amount = 2,
      name = "processing-unit",
      type = "item",
    },

    -- An antenna to broadcast what is found to robots.
    {
      amount = 4,
      name = "copper-cable",
      type = "item",
    },

    -- A robust package for safety in a construction zone.
    {
      amount = 10,
      name = "steel-plate",
      type = "item",
    },
  },

  results = {
    {
      amount = 1,
      name = "bulldozer-equipment",
      type = "item",
    },
  },
};


-- ---------------------- Add the new definitions ----------------------
data:extend{
  bulldozer_equipment,
  bulldozer_item,
  bulldozer_recipe,
};


-- EOF
