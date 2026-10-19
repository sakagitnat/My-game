extends Node3D

# The restaurant map as a sunny 3D world, and the place to play it: the game's own controller (scenes/world.tscn) runs
# underneath with its 2D drawing hidden, keeping the HUD, the rules and placement; this scene draws the world in 3D, turns
# taps on the 3D ground into taps for it, and shows what it shows (the placement ghost, the selection, the guests).
# Real light and shadows, a see-through sea, the shop as a cutaway (tall back walls, low front walls, no roof), a cat chef,
# and each waiting customer as an animal at their seat.

const ZONE := "restaurant"
const PAD := 24                     # land and sea drawn beyond the map edge, so the view never ends in a void
const WATER_Y := -0.12
const PITCH := deg_to_rad(52.0)
const DIST_MIN := 5.0
const DIST_MAX := 34.0
const TAP_SLOP := 12.0
const GUEST_KINDS := ["bunny", "bear", "pig", "duck"]
const SHIRTS := [Color("f09db0"), Color("9ad7bd"), Color("f5d77a"), Color("b9a1e0"), Color("7fb8e0")]

const C_GRASS := Color("6aa843")
const C_GRASS_LT := Color("82bd50")
const C_SAND := Color("dfc48e")
const C_WET := Color("cdb27e")
const C_SEABED := Color("1d5f73")
const C_ROAD := Color("c9a274")
const C_STONE := Color("c2b49a")
const C_DIRT := Color("9c6b45")

var lay: SceneLayout
var g: WorldGrid
var game: Node2D                    # the 2D controller and HUD (scenes/world.tscn) this scene drives
var camera: Camera3D
var target := Vector3(18, 0, 14)
var dist := 15.0
var mat: StandardMaterial3D
var static_mesh: MeshInstance3D
var dynamic_mesh: MeshInstance3D    # plots and crops: rebuilt when a crop grows a stage
var ghost_mesh: MeshInstance3D      # the thing being placed, see-through green (fits) or red
var mark_mesh: MeshInstance3D       # the selection outline
var _crop_key := ""
var _crop_timer := 0.0
var _dirty := false
var _dirty_timer := 0.0
var chef: Animal
var guests: Dictionary = {}         # customer id -> Animal
var labels: Dictionary = {}         # customer id -> Label3D (the order above the guest)
var touches: Dictionary = {}
var pinch_dist := 0.0
var pressing := false
var dragged := false
var press_pos := Vector2.ZERO
var font: Font

func _ready() -> void:
	lay = GameState.layout_for(ZONE)
	g = GameState.grid(ZONE)
	mat = MeshBatch.material()
	font = load("res://assets/fonts/NotoSansThai_400Regular.ttf")
	_environment()
	_camera()
	_ground()
	_sea()
	_rebuild()
	_overlays()
	_animals()
	game = load("res://scenes/world.tscn").instantiate()
	game.host_3d = self
	add_child(game)
	GameState.changed.connect(func() -> void: _dirty = true)

# ------------------------------------------------------------------ light and sky
func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5fa8e0")
	sky_mat.sky_horizon_color = Color("cfe8f3")
	sky_mat.ground_horizon_color = Color("cfe8f3")
	sky_mat.ground_bottom_color = Color("6aa8b8")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # a fixed soft sky-blue fill: the sky as a light source washes out in the web renderer
	env.ambient_light_color = Color("c4d9e6")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

func _camera() -> void:
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.far = 400.0
	add_child(camera)
	var sc := lay.start_cell()
	target = Vector3(sc.x + 2.0, 0, sc.y + 4.0)
	_place_camera()

func _place_camera() -> void:
	target.x = clampf(target.x, 0.0, lay.cells.x)
	target.z = clampf(target.z, 0.0, lay.cells.y)
	dist = clampf(dist, DIST_MIN, DIST_MAX)
	camera.position = target + Vector3(0, sin(PITCH), cos(PITCH)) * dist
	camera.look_at(target)
	if game != null:
		game.camera.position = _to_2d(target)   # placement starts where the camera looks

# 3D ground (x, z in cells) <-> the 2D game's world (Iso pixels).
func _to_2d(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * Iso.TILE_W

func _from_2d(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x / Iso.TILE_W, y, p.y / Iso.TILE_W)

# Where a point of the 2D game's world shows on screen (the HUD puts its bubbles there).
func screen_of(world_pos: Vector2) -> Vector2:
	var p := _from_2d(world_pos, 0.6)
	if camera.is_position_behind(p):
		return Vector2(-1000, -1000)
	return camera.unproject_position(p)

# ------------------------------------------------------------------ ground: one mesh, heights and colours per cell corner
func _tile(c: Vector2i) -> int:
	return lay.tile_at(c.clamp(Vector2i.ZERO, lay.cells - Vector2i.ONE))

func _corner_height(vx: int, vy: int) -> float:
	var cx := clampi(vx, 0, lay.cells.x)
	var cy := clampi(vy, 0, lay.cells.y)
	var f := lay.vertex_field(cx, cy)
	if f <= 0.0:
		return -0.2 + f * 0.9                                      # sea bed, deeper away from the shore
	var d := lay.vertex_distance(cx, cy)
	var shore := 1.0 - clampf(d / 2.2, 0.0, 1.0)
	var bump := (Noise2D.value(vx * 0.4, vy * 0.4, 5) - 0.5) * 0.06 * (1.0 - shore)
	return 0.03 - 0.23 * shore * shore + bump

func _corner_color(vx: int, vy: int) -> Color:
	var col := Color(0, 0, 0)
	for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var t := _tile(Vector2i(vx, vy) + o)
		var c: Color
		match t:
			SceneLayout.Tile.SAND: c = C_SAND
			SceneLayout.Tile.WATER: c = C_SAND
			SceneLayout.Tile.ROAD: c = C_ROAD
			SceneLayout.Tile.PAVEMENT: c = C_STONE
			SceneLayout.Tile.DIRT: c = C_DIRT
			SceneLayout.Tile.FLOOR: c = C_STONE
			_: c = C_GRASS.lerp(C_GRASS_LT, Noise2D.value(vx * 0.21, vy * 0.21, 3))
		col += c * 0.25
	var h := _corner_height(vx, vy)
	if h < 0.0:
		col = col.lerp(C_WET, clampf(-h * 6.0, 0.0, 1.0))           # wet sand at the waterline
	if h < -0.2:
		col = C_WET.lerp(C_SEABED, clampf((-h - 0.2) * 2.0, 0.0, 1.0))
	return col

func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := lay.cells.x + PAD * 2 + 1
	var h := lay.cells.y + PAD * 2 + 1
	for j in h:
		for i in w:
			var vx := i - PAD
			var vy := j - PAD
			st.set_color(_corner_color(vx, vy))
			st.add_vertex(Vector3(vx - 0.5, _corner_height(vx, vy), vy - 0.5))
	for j in h - 1:
		for i in w - 1:
			var a := j * w + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + w)
			st.add_index(a + 1); st.add_index(a + w + 1); st.add_index(a + w)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

func _sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(lay.cells.x + PAD * 2 + 200, lay.cells.y + PAD * 2 + 200)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water3d.gdshader")
	mi.material_override = sm
	mi.position = Vector3(lay.cells.x * 0.5, WATER_Y, lay.cells.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ------------------------------------------------------------------ what stands in the world
func _rect_of(origin: Vector2i, fp: Vector2i) -> Rect2:
	# units are half cells; cell c spans c - 0.5 .. c + 0.5 (as in the 2D game)
	return Rect2(Vector2(origin) * 0.5 - Vector2(0.5, 0.5), Vector2(fp) * 0.5)

func _floor_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for y in lay.cells.y:
		for x in lay.cells.x:
			if lay.tile_at(Vector2i(x, y)) == SceneLayout.Tile.FLOOR:
				var cr := Rect2(Vector2(x - 0.5, y - 0.5), Vector2.ONE)
				r = cr if first else r.merge(cr)
				first = false
	return r

func _rebuild() -> void:
	if static_mesh != null:
		static_mesh.queue_free()
	static_mesh = _add_mesh(_static_batch())
	_crop_key = ""
	_dynamic_world()

func _static_batch() -> MeshBatch:
	var b := MeshBatch.new()
	var shop := _floor_rect()
	# the shop: a wooden floor a step up, walls from the map, a menu board by the door
	for y in lay.cells.y:
		for x in lay.cells.x:
			var t := lay.tile_at(Vector2i(x, y))
			if t == SceneLayout.Tile.FLOOR:
				var plank := Props3D.WOOD_LT if (y % 2 == 0) else Props3D.WOOD
				b.box(Vector3(x - 0.5, 0.0, y - 0.5), Vector3(x + 0.5, 0.1, y), plank)
				b.box(Vector3(x - 0.5, 0.0, y), Vector3(x + 0.5, 0.1, y + 0.5), plank.lerp(Props3D.WOOD_DK, 0.12))
			elif t == SceneLayout.Tile.PAVEMENT:
				var tone := C_STONE.lerp(Color("bcae94"), Noise2D.hash2(x, y, 9) * 0.6)
				b.box(Vector3(x - 0.47, 0.0, y - 0.47), Vector3(x + 0.47, 0.06, y + 0.47), tone)
	for key in lay.walls:
		var parts: PackedStringArray = str(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var kind: String = lay.walls[key]
		if parts[2] == "n":
			Props3D.wall(b, x - 0.5, x + 0.5, y - 0.5, kind)
		else:
			Props3D.wall(b, y - 0.5, y + 0.5, x - 0.5, kind, true)
	if shop.size != Vector2.ZERO:
		for p in [shop.position, Vector2(shop.end.x, shop.position.y)]:          # corner posts so the cutaway walls end cleanly
			b.box(Vector3(p.x - 0.1, 0, p.y - 0.1), Vector3(p.x + 0.1, 2.45, p.y + 0.1), Props3D.WHITE)
		var door_x := shop.position.x + shop.size.x * 0.5
		b.box(Vector3(door_x + 1.2, 0, shop.position.y - 0.9), Vector3(door_x + 1.25, 0.9, shop.position.y - 0.85), Props3D.WOOD_DK)   # menu board
		b.box(Vector3(door_x + 0.95, 0.5, shop.position.y - 0.95), Vector3(door_x + 1.5, 1.05, shop.position.y - 0.9), Props3D.STEEL)
		b.box(Vector3(door_x + 1.0, 0.55, shop.position.y - 0.951), Vector3(door_x + 1.45, 0.6, shop.position.y - 0.95), Props3D.WHITE)
		_beach(b, shop)
	# placed things that never change shape (plots are dynamic)
	for origin in g.objects:
		var id: String = g.objects[origin]
		if id == "farm_plot_01":
			continue
		var r := _rect_of(origin, g.footprints[origin])
		_object(b, id, Vector3(r.get_center().x, 0, r.get_center().y), r.size.x, r.size.y, int(g.facings.get(origin, 0)), true)
	for origin in g.tops:
		var r := _rect_of(origin, g.top_footprints[origin])
		Props3D.vase(b, Vector3(r.get_center().x, 0.55, r.get_center().y), str(g.tops[origin]) == "rest_vase_large_01")
	# trees, rocks and bushes: palms near the beach, leafy trees inland
	for c in g.blocked:
		var kind: String = g.blocked[c]
		var at := Vector3(c.x, _corner_height(c.x, c.y), c.y)
		var seed := int(Noise2D.hash2(c.x, c.y, 13) * 1000.0)
		match kind:
			"tree":
				if lay.edge_distance(c) < 7:
					Props3D.palm(b, at, seed)
				else:
					Props3D.tree(b, at, seed, Noise2D.hash2(c.x, c.y, 17) < 0.35)
			"rock":
				Props3D.rock(b, at, seed)
			_:
				Props3D.bush(b, at, seed)
	# a sign on every block of land for sale
	for py in g.parcel_grid().y:
		for px in g.parcel_grid().x:
			if g.can_buy_parcel(Vector2i(px, py)):
				var mid := Vector2(px, py) * WorldGrid.PARCEL + Vector2.ONE * (WorldGrid.PARCEL * 0.5 - 0.5)
				var h := _corner_height(int(mid.x), int(mid.y))
				b.cyl(Vector3(mid.x, h, mid.y), 0.04, 0.9, Props3D.WOOD_DK)
				b.box(Vector3(mid.x - 0.3, h + 0.6, mid.y - 0.03), Vector3(mid.x + 0.3, h + 0.95, mid.y + 0.03), Color("e8c98a"))
				b.ball(Vector3(mid.x, h + 0.78, mid.y + 0.05), Vector3(0.09, 0.09, 0.02), Color("f3c445"))
	return b

func _object(b: MeshBatch, id: String, at: Vector3, w: float, d: float, facing: int, turned_fp: bool) -> void:
	# the model is built facing the front; a footprint already turned sideways is turned back first
	var mw := d if (turned_fp and facing % 2 == 1) else w
	var md := w if (turned_fp and facing % 2 == 1) else d
	match id:
		"rest_table_small_01": Props3D.table(b, at, mw, md, facing)
		"rest_stove_01": Props3D.stove(b, at, mw, md, facing)
		"rest_vase_large_01": Props3D.vase(b, at, true)
		"rest_vase_small_01": Props3D.vase(b, at, false)
		"farm_fence_01": Props3D.fence(b, at, mw, md)
		"farm_coop_01": Props3D.coop(b, at, mw, md)
		"farm_plot_01": Props3D.plot(b, at, mw, md, "", 0)

func _beach(b: MeshBatch, shop: Rect2) -> void:
	# a pier from the terrace steps out over the bay, a rowing boat, an umbrella and two loungers on the sand
	var x := shop.position.x + shop.size.x * 0.5
	var z := shop.end.y
	while z < lay.cells.y - 1 and lay.tile_at(Vector2i(int(x), int(z + 0.5))) != SceneLayout.Tile.WATER:
		z += 1.0
	Props3D.pier(b, x - 0.6, x + 0.6, z - 1.0, z + 5.0, 0.12)
	Props3D.boat(b, Vector3(x + 1.6, WATER_Y + 0.02, z + 4.0))
	for i in 2:
		var sx := x - 5.0 - i * 2.4
		var sz := z - 1.6
		var h := _corner_height(int(sx), int(sz))
		Props3D.umbrella(b, Vector3(sx + 0.7, h, sz - 0.6), [Color("e8634a"), Color("3d7fb8")][i])
		Props3D.lounger(b, Vector3(sx, h, sz), [Color("f3cd5a"), Color("fbf7ef")][i])

func _add_mesh(b: MeshBatch, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not b.is_empty():
		mi.mesh = b.mesh()
	mi.material_override = m if m != null else mat
	add_child(mi)
	return mi

# Plots and crops: rebuilt only when a crop moves to the next stage.
func _plot_stage(origin: Vector2i) -> int:
	var p := GameState.progress(ZONE, origin)
	if p < 0.0:
		return 0
	return 4 if p >= 1.0 else 1 + int(p * 3.0)

func _dynamic_world() -> void:
	var key := ""
	for origin in g.objects:
		if g.objects[origin] == "farm_plot_01":
			key += "%s:%d;" % [origin, _plot_stage(origin)]
	if key == _crop_key and dynamic_mesh != null:
		return
	_crop_key = key
	var b := MeshBatch.new()
	for origin in g.objects:
		if g.objects[origin] != "farm_plot_01":
			continue
		var r := _rect_of(origin, g.footprints[origin])
		var st: Dictionary = g.states.get(origin, {})
		Props3D.plot(b, Vector3(r.get_center().x, 0, r.get_center().y), r.size.x, r.size.y, str(st.get("crop", "")), _plot_stage(origin))
	if dynamic_mesh != null:
		dynamic_mesh.queue_free()
	dynamic_mesh = _add_mesh(b)

# ------------------------------------------------------------------ what the controller shows: ghost and selection
func _overlays() -> void:
	ghost_mesh = MeshInstance3D.new()
	add_child(ghost_mesh)
	mark_mesh = MeshInstance3D.new()
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.92, 0.45, 0.55)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_mesh.material_override = mm
	mark_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark_mesh)

# Called by the controller whenever what it shows changes (its _redraw_all).
func view_changed() -> void:
	if game == null:
		return
	# the ghost: the real model, see-through, green where it fits and red where it does not
	ghost_mesh.mesh = null
	if game.placing_id != "":
		var id: String = game.placing_id
		var sz: Vector2i = Catalog.size_facing(id, game.placing_facing)
		var origin: Vector2i = GameState.footprint_origin(game.ghost_cell, sz)
		var r := _rect_of(origin, sz)
		var b := MeshBatch.new()
		var y := 0.55 if Catalog.is_top(id) else 0.02
		b.box(Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y + 0.03, r.end.y), Color.WHITE)
		_object(b, id, Vector3(r.get_center().x, y - 0.02 if Catalog.is_top(id) else 0.0, r.get_center().y), r.size.x, r.size.y, game.placing_facing, true)
		ghost_mesh.mesh = b.mesh()
		var gm := StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.vertex_color_is_srgb = true
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var ok: bool = game.view.ghost_status == "ok"
		gm.albedo_color = Color(0.75, 1.0, 0.75, 0.7) if ok else Color(1.0, 0.55, 0.5, 0.7)
		ghost_mesh.material_override = gm
		ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the selection: a soft yellow mat under the chosen thing, tree or block of land
	var sel := Rect2()
	if game.selected_origin != WorldGrid.NONE:
		var fps: Dictionary = g.top_footprints if game.selected_top else g.footprints
		if fps.has(game.selected_origin):
			sel = _rect_of(game.selected_origin, fps[game.selected_origin])
	elif game.selected_obstacle != WorldGrid.NONE:
		sel = Rect2(Vector2(game.selected_obstacle) - Vector2(0.5, 0.5), Vector2.ONE)
	elif game.selected_land != WorldGrid.NONE:
		var p := WorldGrid.parcel_of(game.selected_land)
		sel = Rect2(Vector2(p * WorldGrid.PARCEL) - Vector2(0.5, 0.5), Vector2.ONE * WorldGrid.PARCEL)
	if sel.size == Vector2.ZERO:
		mark_mesh.mesh = null
	else:
		var box := BoxMesh.new()
		box.size = Vector3(sel.size.x + 0.12, 0.04, sel.size.y + 0.12)
		mark_mesh.mesh = box
		mark_mesh.position = Vector3(sel.get_center().x, 0.12, sel.get_center().y)

# ------------------------------------------------------------------ the cat chef and the guests (the real customers)
func _animals() -> void:
	var shop := _floor_rect()
	if shop.size == Vector2.ZERO:
		return
	chef = Animal.new().setup("cat", true)
	chef.position = Vector3(shop.position.x + 3.0, 0.1, shop.position.y + 1.8)
	add_child(chef)
	chef.arrived.connect(_chef_next)
	_chef_next()

func _chef_next() -> void:
	# the chef goes from stove to stove; with no stove yet, around the back of the shop
	var shop := _floor_rect()
	var spots: Array[Vector3] = []
	for o in GameState.restaurant.stoves():
		var r := _rect_of(o, g.footprints[o])
		spots.append(Vector3(r.get_center().x, 0.1, r.end.y + 0.45))
	if spots.is_empty():
		spots.append(Vector3(randf_range(shop.position.x + 1.0, shop.end.x - 1.0), 0.1, shop.position.y + 1.6))
	var p: Vector3 = spots[randi() % spots.size()] + Vector3(randf_range(-0.3, 0.3), 0, 0)
	get_tree().create_timer(randf_range(1.0, 3.0)).timeout.connect(func() -> void:
		if is_instance_valid(chef):
			chef.walk_along([p] as Array[Vector3]))

func _seat_of(c: Dictionary) -> Vector3:
	var u: Vector2i = c.seat_cell
	return Vector3(u.x * 0.5, 0.2, u.y * 0.5)                      # the middle of the cell beside the table

func _sync_guests() -> void:
	var shop := _floor_rect()
	if shop.size == Vector2.ZERO:
		return
	var door := Vector3(shop.position.x + shop.size.x * 0.5, 0.1, shop.position.y)
	var seen := {}
	for c in GameState.restaurant.snapshot_customers():
		var id: int = c.id
		seen[id] = true
		var seat := _seat_of(c)
		if not guests.has(id):                                        # a new customer walks in from the road
			var a := Animal.new().setup(GUEST_KINDS[id % GUEST_KINDS.size()], false, SHIRTS[id % SHIRTS.size()])
			a.position = Vector3(door.x + randf_range(-3.0, 3.0), 0.0, 1.0)
			add_child(a)
			guests[id] = a
			var aisle := Vector3(seat.x, 0.1, seat.z - 1.0)
			a.walk_along([Vector3(door.x, 0.05, door.z - 1.2), Vector3(door.x, 0.1, door.z + 1.2), Vector3(door.x, 0.1, aisle.z), aisle, seat] as Array[Vector3])
			var face := PI * 0.5 if int(c.index) == 0 else -PI * 0.5
			a.arrived.connect(func() -> void: a.rotation.y = face, CONNECT_ONE_SHOT)
			var l := Label3D.new()
			l.font = font
			l.font_size = 40
			l.outline_size = 10
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.pixel_size = 0.006
			add_child(l)
			labels[id] = l
		var label: Label3D = labels[id]
		var a2: Animal = guests[id]
		label.visible = not a2.is_walking()
		label.position = a2.position + Vector3(0, 1.45, 0)
		label.text = Loc.t(Catalog.RECIPES[c.dish].name)            # green when the dish is ready on the counter
		label.modulate = Color("4f8f3a") if c.served_ready else (Color("c8432f") if float(c.patience_frac) < 0.3 else Color("4a3226"))
		label.outline_modulate = Color("fffaf1")
	for id in guests.keys():                                          # served or tired of waiting: walk out to the road
		if seen.has(id):
			continue
		var a: Animal = guests[id]
		guests.erase(id)
		(labels[id] as Label3D).queue_free()
		labels.erase(id)
		a.position.y = 0.1
		a.walk_along([Vector3(door.x, 0.1, a.position.z - 0.8), Vector3(door.x, 0.1, door.z + 1.0), Vector3(door.x, 0.05, door.z - 1.2), Vector3(door.x + randf_range(-4.0, 4.0), 0.0, 0.8)] as Array[Vector3])
		a.arrived.connect(a.queue_free, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	_crop_timer += delta
	if _crop_timer > 1.0:
		_crop_timer = 0.0
		_dynamic_world()
	_dirty_timer += delta
	if _dirty and _dirty_timer > 0.3:                                 # many changes in a row rebuild once
		_dirty = false
		_dirty_timer = 0.0
		_rebuild()
	_sync_guests()

# ------------------------------------------------------------------ input: drag to move, pinch or wheel to zoom, tap to play
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			dragged = true
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if pinch_dist > 0.0:
				dist *= pinch_dist / maxf(d, 1.0)
			pinch_dist = d
			_place_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				dragged = touches.size() >= 2
				press_pos = event.position
			else:
				if pressing and not dragged:
					_tap(event.position)
				pressing = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist /= 1.1
			_place_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
			_place_camera()
	elif event is InputEventMouseMotion and pressing and touches.size() < 2:
		if not dragged and event.position.distance_to(press_pos) > TAP_SLOP:
			dragged = true
		if dragged:
			_pan(event.relative)
			_place_camera()
	elif event is InputEventMagnifyGesture:
		dist /= event.factor
		_place_camera()

func _pan(rel: Vector2) -> void:
	var k := dist / get_viewport().get_visible_rect().size.y * 0.75
	target -= Vector3(rel.x, 0, rel.y / sin(PITCH)) * k

# A tap goes to the first thing along the line of sight: tall things (a tree's crown, a stove) before the ground behind them.
func _tap(screen: Vector2) -> void:
	tap_ground(_pick(screen))

func _pick(screen: Vector2) -> Vector3:
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	for y in [1.6, 1.0, 0.5]:
		if absf(d.y) < 0.001:
			break
		var p: Vector3 = o + d * ((y - o.y) / d.y)
		var c := Vector2i(roundi(p.x), roundi(p.z))
		var u := Vector2i(floori((p.x + 0.5) * 2.0), floori((p.z + 0.5) * 2.0))
		if not g.in_bounds(c):
			continue
		var tall: bool = g.blocked.get(c, "") == "tree" and y > 0.6
		if (g.blocked.has(c) and y <= 1.0) or tall or (g.origin_at(u) != WorldGrid.NONE and y <= 0.5):
			return Vector3(p.x, 0, p.z)
	return o + d * ((0.0 - o.y) / d.y) if absf(d.y) > 0.001 else target

# Sends a tap at a point on the 3D ground to the game.
func tap_ground(p: Vector3) -> void:
	if game != null:
		game._on_tap(_to_2d(p))
