test-plan.txt
=============


Abbreviations
=============

BE = Bulldozer Equipment


Preliminaries
=============

For these tests, for expedience, use a game where an infinity item chest
is available to provide materials as needed, but do not use the "/cheat"
command.  The console command to use is:

```
/c game.player.insert{name="infinity-chest"}
```

All tests assume BE has been installed into Factorio, but may call for a
save-game file that was created without it.

For all tests, ensure the configuration option "Call error on bug" is
set to true.


Adding the mod
==============

Load a game that was saved without BE installed.

Check that the BE technology appears in the tech tree.

Check that the BE preferences are available in the settings menu, both
for the map and the player.

Check that all settings have properly mapped names and hover help texts,
as opposed to a key lookup error.

Open Factoriopedia by Alt-clicking anything.  Go to the Combat tab.

Check BE appears as a "Recipe/Item" and has a properly mapped name and
description.


Research
========


BE unresearched
---------------

Start a new game.

Check that BE technology is available but not researched.

Check that the BE item is not shown in the crafting menu (Combat tab).


BE researched
-------------

Load a game that has:

* The BE prereqs researched.
* BE not researched.

Complete the BE research.

Check that BE technology is now shown as researched.

Check that the BE item is in the crafting menu.  Craft one.


Cliff Explosives unresearched
-----------------------------

Load a game that has:

* BE researched.
* Cliff Explosives not researched.
* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.

Walk near cliffs.

Check that no cliffs are designated for removal.


Cliff Explosives research transition
------------------------------------

Continue the previous test.

Research Cliff Explosives.

Walk near cliffs.

Check cliffs are now designated for removal.


Cliff Explosives already researched
-----------------------------------

Load a game that has:

* BE researched.
* Cliff Explosives researched.
* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.

Walk near cliffs.

Check that cliffs are designated for removal.


Player equipment grid
=====================

For these tests, load a game that has:

* BE researched.
* Cliff Explosives researched.


Equipping BE
------------

Load a game that has:

* A BE item in the player's inventory but not in the equipment grid.
* A portable fusion generator in the grid.

Walk near some trees.

Check that no trees are marked for destruction.

Install the BE into the grid.

Walk near some trees and check they are marked for destruction.


Unequipping BE
--------------

Continue the previous test.

Remove the BE item from the grid.

Walk near some trees.

Check that no trees are marked for destruction.


Start with BE equipped
----------------------

Load a game that has:

* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.

Walk near some trees and check they are marked for destruction.


Mutltiple BE
------------

Load a game that has:

* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.
* Another BE item in the player's inventory.

Walk near some trees and check they are marked for destruction.

Add the second BE item to the grid.

Walk near some trees and check they are marked for destruction.

Remove the first BE item from the grid.

Walk near some trees and check they are marked for destruction.

Remove the second BE item from the grid.

Walk near some trees.

Check that no trees are marked for destruction.


Equipping unpowered BE
----------------------

Load a game that has:

* A BE item in the player's inventory but not in the equipment grid.
* No power source in the grid.

Add the BE item to the grid.

Walk near some trees.

Check that no trees are marked for destruction (BE is unpowered).


Obstacle clearance settings
===========================


Slow obstacle check
-------------------

Load a game that has:

* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.

Walk near some trees, and continue slowly walking through them.

Check that the trees are marked approximately continuously (every 15
ticks).

In the settings menu, change the obstacle check period to 300 ticks.

Walk near some trees, and continue slowly walking through them.

Check that the trees are marked in batches every 5 seconds.


Disable obstacle check
----------------------

Continue the previous test.

In the settings menu, change the obstacle check period to 0.

Walk near some trees.

Check that no trees are marked.


Disable the mod (obstacles)
---------------------------

Load a game that has:

* A BE item in the player's equipment grid.
* A portable fusion generator in the grid.

Walk near some trees and check they are marked.

In settings, disable the mod for the player.

Walk near some trees.

Check that they are not marked.


Disable all clearance types
---------------------------

Load a game that has:

* BE researched.
* Cliff Explosives researched.
* BE and power source in the player's grid.

Go into the settings menu and uncheck all of the options related to
obstacle clearance.

Walk near some trees, rocks, cliffs, and water.

Check that none of them are marked.


Enable clearance one by one
---------------------------

Continue the previous test.

For each of trees, rocks, cliffs, and water, one at a time:

* Enable it in the settings menu.

* Walk near that type of obstacle.

* Check it is marked for destruction.


Entity distance
---------------

Load a game that has:

* BE researched.
* Cliff Explosives researched.
* BE and power source in the player's grid.

Walk near some trees and check that they are marked upon close approach.

In settings, set the obstacle entity radius to 32.

Use F4 and F5 to enable the tile grid, which has thick lines every 32
squares.

Walk toward some trees.

Check that the trees are marked as they cross the 32-unit threshold.


Tile distance
-------------

Continue the previous test.

Walk near some water and check that it is marked upon very close
approach.

In settings, set the tile radius to 32.

Walk to where there is plenty of water onscreen.

Check that the water gets marked at 32 squares away.


Vehicle equipment grid
======================

For these tests, load a game that has:

* BE researched.
* Cliff Explosives researched.
* A BE item in the player's inventory but not in the grid.
* A portable fission generator in the player's inventory.
* A tank and fuel in the player's inventory.


Place a tank
------------

Place a tank on the ground and add fuel.

Drive it near trees.

Check that no trees are marked for destruction.


Add unpowered BE
----------------

Continue the previous test.

Put the BE into the tank's grid.

Drive it near trees.

Check that no trees are marked for destruction (the BE does not have
power).


Power the BE
------------

Continue the previous test.

Put the portable fission generator into the tank's grid.

Drive it near some trees and check they are marked for destruction.


Remove BE
---------

Continue the previous test.

Remove BE from the tank's grid.

Drive it near some trees.

Check that no trees are marked for destruction.


Player landfill creation
========================


No BE
-----

Load a game that has:

* BE researched.
* Logistic robotics researched (so trash inventory exists).
* BE item in player's inventory but not grid.
* Power source in the player's grid.
* 1000 wood, 500 stone, and 500 coal in player's inventory.

Check that no items are being converted to landfill.


Add BE
------

Contine the previous test.

Add BE to the grid.

Check that stone is being converted to landfill.

Before all stone is converted, go into the settings menu and disable
creation of landfill from stone.

Check that stone is no longer converted, but now wood is instead.

Before all wood is converted, go into the settings and disable wood
conversion.

Check that wood is no longer converted, but now coal is instead.

Before all coal is converted, go into the settings and disable coal
conversion.

Check that nothing is being converted.


Conversion from trash
---------------------

Continue the previous test.

Move remaining wood, coal, and stone into the trash inventory.

Go into the settings and enable all conversion.

Check that the remaining trash is all converted.


Slow conversion
---------------

Load a game that has:

* BE researched.
* BE item in player's inventory but not grid.
* Power source in the player's grid.
* 1000 wood, 500 stone, and 500 coal in player's inventory.

Add BE to the grid.

Check that items are converted at a rate of one per second.

Go into settings and change the landfill creation period to 300.

Check that items are converted at a rate of one every 5 seconds.


Conversion disabled
-------------------

Continue the previous test.

Go into settings and change the landfill creation period to 0.

Check that no items are converted.


Disable the mod (conversion)
----------------------------

Load a game that has:

* BE researched.
* BE item in player's inventory but not grid.
* Power source in the player's grid.
* 1000 wood, 500 stone, and 500 coal in player's inventory.

Add BE to the grid.

Check that items are converted.

In settings, disable the mod for the player.

Check that no items are converted.


Vehicle landfill creation
=========================


No BE
-----

Load a game that has:

* BE researched.
* Logistic system researched (requester chests, etc.).
* A fueled tank on the ground.
* BE item in player's inventory.
* Power source in the tank's grid.
* No BE in the tank's grid.
* 1000 wood, 500 stone, and 500 coal in tank's inventory.

Check that no conversion is happening of items in the tank's inventory.

Drive the tank forward a little.

Check that, still, no conversion is happening.


Add BE
------

Continue the previous test.

Put BE into the tank's inventory.

Check that no conversion is happening (the tank is not moving).

Drive the tank forward a little.

Check that items are converted to landfill that is placed in the tank's
main inventory.


Conversion from trash
---------------------

Continue the previous test.

Before all items are converted, check the "trash unrequested" box so
they all move to the tank's trash inventory.

Check that remaining items are begin converted to landfill that is
placed in the tank's trash inventory.

Before all items are converted, uncheck "trash unrequested".

Check that all remaining items are converted to landfill, with the
newly converted items going into the main inventory.


Character lifecycle
===================


Die with BE equipped
--------------------

Load a save that has:

* BE and a power source equipped in the player's grid.

Get killed by biters.

Check that the character can respawn.

Without any armor equipped, retrieve the character corpse, such that
the corpse armor becomes equipped.

Walk toward some trees.

Check that the trees get marked.


Swap armor
----------

Load a save that has:

* One set of armor equipped with BE and power.
* Another set of armor in the inventory with no BE or power.

Walk toward some trees, check they get marked.

Swap in the armor without BE.

Walk toward some trees, check they do not get marked.

Swap back to the first armor.

Walk toward some trees, check they get marked.


Join and leave multiplayer
--------------------------

On one computer, load a save that has:

* A remote player with BE and power in the grid.

On another computer, join that game as that player.

Walk toward trees, check they get marked.

Leave the game.

Rejoin the game.

Walk toward trees, check they get marked.

Unequip BE.

Walk toward trees, check they are not marked.

Leave and rejoin.

Walk toward trees, check they are not marked.


Vehicle lifecycle
=================


Place a vehicle with BE
-----------------------

Load a save that has:

* BE and a power source in the equipment grid of a vehicle that has
  been picked up (so it is an item, not an entity).
* No other BE equipped in a vehicle or character.

My save: bulldozer_test_place_be_tank

Place the vehicle down.

Drive toward some trees.

Check that the trees get marked.

Pick up the vehicle.

Walk toward some trees and check they are not marked.

Place the vehicle down again.

Drive toward trees and check they are marked.


Vehicle with BE destroyed
-------------------------

Load a save that has:

* BE equipped in a vehicle grid with power, vehicle placed on the ground.
* Another vehicle with no equipment in the player's inventory.
* BE, power source, and fuel in player's inventory.

My save: bulldozer_test_destroy_be_tank

Destroy the vehicle with gunfire.

Check that the game does not crash.

Place the new vehicle.

Put BE, power source, and fuel into it.

Drive toward some trees.

Check that the trees are marked.


Performance
===========

Load a reasonably large map that has at least 30 trains.

Put BE into the player's grid with a power source.

Press F4 and configure the debug view to show the detailed time
information.

Press F5 to enable debug view.

While standing still, check that the average time per tick for BE is
less than 5 us (0.005 in the time display).

While moving, check that the average time per tick is less than 15 us.


EOF
