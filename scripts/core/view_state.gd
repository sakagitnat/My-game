class_name ViewState
extends RefCounted

# What the player is doing right now, handed to the renderer read-only.
# world.gd (game side) writes it; scripts/visuals/ (graphics side) only reads it.
var zone: String = "restaurant"
var ghost_id: String = ""                       # "" when not placing or moving
var ghost_cell: Vector2i = Vector2i.ZERO        # in units: finer than cells, Iso.SUB per cell (see Iso)
var ghost_facing: int = 0                       # turn of the ghost: 0 front, 1 left, 2 back, 3 right
var ghost_status: String = ""                   # "ok" | "blocked" | "occupied" | "locked" | "no_coins" | "level" | "invalid" | "area"
var moving_origin: Vector2i = WorldGrid.NONE    # NONE unless an existing object is being moved
var selected_origin: Vector2i = WorldGrid.NONE  # NONE when no object is selected
var selected_obstacle: Vector2i = WorldGrid.NONE
var selected_land: Vector2i = WorldGrid.NONE    # a cell of an owned block that has its floor/grass bubble open

# Restaurant (read-only copies refreshed about twice a second; see Restaurant.snapshot_customers):
# customers: [{id, seat_cell, table, index, dish, patience_frac, served_ready}], counter: [dish ids]
var customers: Array = []
var counter: Array = []

# Map editor (world.gd writes these): the editor draws its cell grid, block outlines and block labels.
var edit_mode: bool = false
var edit_tool: String = ""
