class_name ViewState
extends RefCounted

# What the player is doing right now, handed to the renderer read-only.
# world.gd (game side) writes it; scripts/visuals/ (graphics side) only reads it.
var zone: String = "restaurant"
var ghost_id: String = ""                       # "" when not placing or moving
var ghost_cell: Vector2i = Vector2i.ZERO
var ghost_status: String = ""                   # "ok" | "blocked" | "occupied" | "locked" | "no_coins" | "level" | "invalid"
var moving_origin: Vector2i = WorldGrid.NONE    # NONE unless an existing object is being moved
var selected_origin: Vector2i = WorldGrid.NONE  # NONE when no object is selected
var selected_obstacle: Vector2i = WorldGrid.NONE
