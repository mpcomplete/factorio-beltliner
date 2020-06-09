# Factorio BeltLiner

This is a mod for [Factorio](http://factorio.com) for making belt placement
easier. Place a belt or row of belts, then shift+click a destination to connect
the belts in a straight line. The mod will orient the belts in the right
direction, use undergrounds to avoid obstacles, and handle multiple belt
corners.

# How to use

Place any belt as a starting point. Move cursor to target destination, then
place a ghost of that belt (default Shift+Click). BeltLiner will detect
parallel belt lanes at the starting location, and connect the start and
destination in a straight line with that many parallel lanes. The orientation
of belts is handled automatically, so you never have to rotate or place corners
manually.

# Features

* Works with any belt type.
* Uses underground belts to avoid obstacles.
* Handles parallel belt lanes automatically.
* Handles multiple belt corners automatically.
* Places belt ghosts (blueprints) when outside placement range (mods like Long Reach can extend this range).
* Works in forward or reverse. (default toggle is Control+Shift+R).

# Limitations

BeltLiner uses "ghost placement" to detect when you want to draw a belt line.
Due to the way Factorio handles ghost placement, this doesn't work well when
you don't have any belts remaining in your inventory; placement is disabled in
that case.

BeltLiner detects the cursor location as you move using temporary invisible
entities centered near your cursor. If you move your mouse too fast, or zoom
out and in to a different location, BeltLiner will lose track of your cursor
until you mouse over another entity. This only affects the drawing of the blue
indicator arrows.
