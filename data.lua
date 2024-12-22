-- data.lua

local mod_name = "__BulldozerEquipment__";


-- ----------------------------- Equipment -----------------------------
-- Unfortunately, there is not a generic category of equipment.
-- Instead, one must extend one of the types in the base game.  I use
-- an exoskeleton with the movement bonus set to 0.
local bulldozer_equipment = table.deepcopy(
  data.raw["movement-bonus-equipment"]["exoskeleton-equipment"]);

bulldozer_equipment.name = "bulldozer-equipment";

bulldozer_equipment.sprite = {
  filename = mod_name .. "/graphics/equipment/bulldozer.png",
  width = 64,
  height = 64,
  priority = "medium",
};

-- Nominal energy cost.  But since this is based on exoskeleton, it
-- only drains while moving.
bulldozer_equipment.energy_consumption = "50kW";

bulldozer_equipment.movement_bonus = 0;

bulldozer_equipment.shape = {
  width = 1,
  height = 1,
  type = "full",
};

bulldozer_equipment.order = "b-i-b";


-- ------------------------------- Item --------------------------------
local bulldozer_item = table.deepcopy(data.raw.item["exoskeleton-equipment"]);
bulldozer_item.name                      = "bulldozer-equipment";
bulldozer_item.icon                      = mod_name .. "/graphics/icons/bulldozer.png";
bulldozer_item.order                     = "c[bulldozer]";
bulldozer_item.place_as_equipment_result = "bulldozer-equipment";


-- ------------------------------ Recipe -------------------------------
local bulldozer_recipe = {
  name = "bulldozer-equipment",
  type = "recipe",

  enabled = false,            -- Unlock with research.
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


-- ---------------------------- Technology -----------------------------
local bulldozer_technology = {
  name = "bulldozer-equipment",
  type = "technology",
  effects = {
    {
      type = "unlock-recipe",
      recipe = "bulldozer-equipment",
    },
  },
  icon = mod_name .. "/graphics/technology/bulldozer-equipment.png",
  icon_size = 64,

  prerequisites = {
    -- It seems like this is a sort of "utility" function, and a
    -- somewhat advanced capability, so perhaps it makes sense to put it
    -- behind utility (yellow) science.
    "utility-science-pack",

    -- Exoskeleton has this prerequisite, so I will too.
    "solar-panel-equipment",

    -- Ensure the radar item is researched.
    "radar",
  },

  unit = {
    count = 50,
    ingredients = {
      {
        "automation-science-pack",
        1
      },
      {
        "logistic-science-pack",
        1
      },
      {
        "chemical-science-pack",
        1
      },
      {
        "utility-science-pack",
        1
      },
    },
    time = 30,
  },
};


-- ---------------------- Add the new definitions ----------------------
data:extend{
  bulldozer_equipment,
  bulldozer_item,
  bulldozer_recipe,
  bulldozer_technology,
};


-- EOF
