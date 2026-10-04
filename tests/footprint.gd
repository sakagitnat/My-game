extends SceneTree

# Room a thing reserves, where it blocks walking, the picture's own box, and the shared draw order (feet).
var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# block rectangle: defaults to the whole footprint, empty for a plot, turns with the footprint
	check(Catalog.block_rect("rest_table_small_01") == Rect2i(0, 0, 4, 4), "a table blocks its whole footprint")
	check(Catalog.block_rect("farm_plot_01").size == Vector2i.ZERO, "a plot can be walked over")
	var back_row := Rect2i(0, 0, 4, 1)   # a 4x2 thing that blocks only its back row
	check(Catalog.turn_rect(back_row, Vector2i(4, 2), 1) == Rect2i(1, 0, 1, 4), "a quarter turn: the back row becomes the right column of the 2x4 footprint")
	check(Catalog.turn_rect(back_row, Vector2i(4, 2), 2) == Rect2i(0, 1, 4, 1), "a half turn: the back row becomes the front row")
	check(Catalog.turn_rect(back_row, Vector2i(4, 2), 3) == Rect2i(0, 0, 1, 4), "three quarters: the left column")
	check(Catalog.turn_rect(back_row, Vector2i(4, 2), 4) == back_row, "four quarter turns come back to the start")
	check(Catalog.block_rect("rest_stove_01", 1) == Rect2i(0, 0, 4, 4), "a square footprint blocks the same square turned")

	# blocking in the world
	var g := WorldGrid.new(Vector2i(40, 40))
	g.owned_parcels = {}   # ownership does not matter here
	g.objects[Vector2i(10, 10)] = "rest_table_small_01"
	g.footprints[Vector2i(10, 10)] = Vector2i(4, 4)
	for c in g.cells_of(Vector2i(10, 10), Vector2i(4, 4)):
		g.occupied[c] = Vector2i(10, 10)
	g.objects[Vector2i(20, 10)] = "farm_plot_01"
	g.footprints[Vector2i(20, 10)] = Vector2i(4, 4)
	for c in g.cells_of(Vector2i(20, 10), Vector2i(4, 4)):
		g.occupied[c] = Vector2i(20, 10)
	g.blocked[Vector2i(3, 3)] = "tree"
	check(g.blocks_walk(Vector2i(11, 12)), "a table's units block walking")
	check(not g.blocks_walk(Vector2i(14, 10)), "next to the table is free")
	check(not g.blocks_walk(Vector2i(21, 11)), "a plot does not block walking")
	check(g.blocks_walk(Vector2i(6, 7)) and g.blocks_walk(Vector2i(7, 6)), "a tree blocks all four units of its cell")
	check(not g.blocks_walk(Vector2i(8, 6)), "the next cell of a tree is free")

	# the picture's box
	var tex := Vector2(256, 256)
	var foot := Vector2(100, 200)
	var plain: Rect2 = ArtCatalog.sprite_rect({}, tex, foot, 128.0)
	check(plain == Rect2(Vector2(36, 72), Vector2(128, 128)), "by default the picture is as wide as the footprint, standing on its foot")
	var wide: Rect2 = ArtCatalog.sprite_rect({"w": 8}, tex, foot, 128.0)
	check(wide.size == Vector2(256, 256) and wide.position == Vector2(-28, -56), "a wider box lets the picture stick out without being squeezed (8 units = 256 px)")
	var moved: Rect2 = ArtCatalog.sprite_rect({"dx": 2, "dy": 1}, tex, foot, 128.0)
	check(moved.position == Vector2(36 + 64, 72 + 32), "dx and dy move the picture in units (32 px)")
	check(ArtCatalog.art_box("rest_table_small_01").is_empty(), "no entry: the default box")

	# draw order: feet decide, not sizes
	var table_key := Iso.footprint_depth(Vector2i(10, 10), Vector2i(4, 4))
	check(Iso.depth_key(Vector2(12, 15)) > table_key, "a person standing south of the table's bottom edge is drawn after it")
	check(Iso.depth_key(Vector2(12, 13)) < table_key, "a person standing north of the bottom edge is drawn before it")
	var tree_key := Iso.depth_key(Vector2(3 * Iso.SUB, (3 + 1) * Iso.SUB))
	check(Iso.footprint_depth(Vector2i(6, 6), Vector2i(2, 2)) == tree_key, "a tree and a 1-cell thing in the same cell have the same key")

	if failures == 0:
		print("PASS: footprint (block rectangle, walking, picture box, draw order)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
