extends SceneTree
# Screenshots of the real game with a furnished shop and a planted garden (needs a display; on a server use xvfb-run):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --script tools/screenshot/shot.gd -- OUTDIR
# Writes OUTDIR/<view>.png for each view in VIEWS (camera cell and zoom). Uses its own save file, never the player's.

const VIEWS := {
	"overview": [Vector2(24, 20), 0.42],
	"shop": [Vector2(19, 13), 0.95],
	"garden": [Vector2(32, 13), 0.95],
	"beach": [Vector2(20, 24), 0.8],
}

func _initialize() -> void:
	call_deferred("run")

func _place(gs, id: String, unit: Vector2i, facing := 0) -> void:
	var r: String = gs.place_object("restaurant", unit, id, facing)
	if r != "ok":
		print("  not placed ", id, " at ", unit, ": ", r)

func run() -> void:
	var out := "shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var gs = root.get_node("/root/GameState")
	gs.ask_names = false
	gs.autosave = false
	gs.save_path = "user://screenshot_salvora.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.clock_override = 1000.0
	gs.reset()
	gs.level = 10
	gs.coins = 999999
	var grid = gs.grid("restaurant")
	var lay = gs.layout_for("restaurant")
	# furnish the shop: units are half cells; the shop floor is every owned 'f' cell
	var floor_cells: Array[Vector2i] = []
	for y in range(lay.cells.y):
		for x in range(lay.cells.x):
			if lay.tile_at(Vector2i(x, y)) == SceneLayout.Tile.FLOOR:
				floor_cells.append(Vector2i(x, y))
	if not floor_cells.is_empty():
		var lo: Vector2i = floor_cells[0]
		var hi: Vector2i = floor_cells[0]
		for c in floor_cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y)); hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var u0 := lo * Iso.SUB
		_place(gs, "rest_stove_01", u0 + Vector2i(3, 2))
		_place(gs, "rest_stove_01", u0 + Vector2i(7, 2))
		for i in range(3):
			_place(gs, "rest_table_small_01", u0 + Vector2i(4 + i * 6, 12))
			_place(gs, "rest_table_small_01", u0 + Vector2i(4 + i * 6, 18))
		_place(gs, "rest_vase_large_01", u0 + Vector2i(4, 12))
		_place(gs, "rest_vase_small_01", u0 + Vector2i(16, 18))
	# the garden: plots on the owned blocks outside the shop, planted at different times so every stage shows
	var plots := 0
	var seeds := ["wheat", "tomato", "cabbage"]
	for b in lay.starts:
		for oy in range(1, 5, 2):
			for ox in range(1, 5, 2):
				var c: Vector2i = b * 6 + Vector2i(ox, oy)
				if lay.tile_at(c) == SceneLayout.Tile.FLOOR or not lay.allows("farm", c):
					continue
				var unit := c * Iso.SUB + Vector2i(1, 1)
				if gs.place_object("restaurant", unit, "farm_plot_01") != "ok":
					continue
				var crop: String = seeds[plots % 3]
				gs.clock_override = 1000.0 - float(plots % 4) * Catalog.CROPS[crop].time * 0.3
				gs.interact("restaurant", c * Iso.SUB, crop)
				plots += 1
	gs.clock_override = 1000.0
	print("plots planted: ", plots)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in range(20):
		await process_frame
	for name in VIEWS:
		var v: Array = VIEWS[name]
		world.camera.position = Iso.cell_to_world_f(v[0])
		world.camera.zoom = Vector2.ONE * float(v[1])
		world._redraw_all()                                  # the ground only draws what is on screen, as after a drag
		for i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("saved ", name)
	quit()
