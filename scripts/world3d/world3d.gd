extends Node3D

# The 3D preview of the restaurant map: the same map and save as the 2D game, drawn as a sunny 3D island with real light,
# shadows and a see-through sea, the shop as a cutaway (tall back walls, low front walls, no roof), a cat chef and animal
# guests. Things the player has not placed yet show as samples, so the scene is never empty. Look only: playing still
# happens in the 2D game (Back button).

const ZONE := "restaurant"
const PAD := 24                     # land and sea drawn beyond the map edge, so the view never ends in a void
const WATER_Y := -0.12
const PITCH := deg_to_rad(52.0)
const DIST_MIN := 5.0
const DIST_MAX := 34.0

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
var camera: Camera3D
var target := Vector3(18, 0, 14)
var dist := 15.0
var dynamic_mesh: MeshInstance3D    # plots and crops: rebuilt when a crop grows a stage
var _crop_key := ""
var _crop_timer := 0.0
var touches: Dictionary = {}
var pinch_dist := 0.0
var chef: Animal
var guests: Array[Animal] = []
var seats: Array[Vector3] = []
var seat_taken: Dictionary = {}
var _guest_timer := 2.0
var demo_objects: Array = []        # [id, centre (Vector3), w, d, facing, state] shown when the shop or garden is still empty
var mat: StandardMaterial3D

func _ready() -> void:
	lay = GameState.layout_for(ZONE)
	g = GameState.grid(ZONE)
	mat = MeshBatch.material()
	_environment()
	_camera()
	_ground()
	_sea()
	_samples()
	_static_world()
	_dynamic_world()
	_animals()
	_ui()

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

func _has(id: String) -> bool:
	return g.objects.values().has(id)

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

# Sample furniture and a sample garden when the player has none yet: drawn only, never added to the save.
func _samples() -> void:
	var shop := _floor_rect()
	if shop.size == Vector2.ZERO:
		return
	if not _has("rest_table_small_01") and not _has("rest_stove_01"):
		for i in 2:
			demo_objects.append(["rest_stove_01", Vector3(shop.position.x + 1.6 + i * 1.7, 0, shop.position.y + 0.62), 1.5, 1.0, 0, {}])
		for i in 2:
			demo_objects.append(["rest_stove_01", Vector3(shop.end.x - 1.6 - i * 1.7, 0, shop.position.y + 0.62), 1.5, 1.0, 0, {}])
		for row in 2:
			for col in 3:
				var c := Vector3(shop.position.x + 2.5 + col * 3.5, 0, shop.position.y + 5.0 + row * 3.5)
				demo_objects.append(["rest_table_small_01", c, 1.5, 1.0, 0, {}])
				if (row + col) % 2 == 0:
					demo_objects.append(["rest_vase_large_01", c + Vector3(0.25, 0.55, -0.1), 0.5, 0.5, 0, {}])
	if not _has("farm_plot_01"):
		var gx := shop.end.x + 6.0
		var gz := shop.position.y + 1.5
		var crops := ["tomato", "wheat", "cabbage"]
		for row in 3:
			for col in 3:
				var stage := (row * 3 + col) % 5
				demo_objects.append(["farm_plot_01", Vector3(gx + col * 2.6, 0, gz + row * 2.6), 2.0, 2.0, 0, {"crop": crops[(row + col) % 3], "stage": maxi(stage, 1)}])
		demo_objects.append(["farm_coop_01", Vector3(gx + 9.0, 0, gz + 5.5), 3.0, 3.0, 0, {}])
		for i in 9:
			demo_objects.append(["farm_fence_01", Vector3(gx - 1.4 + i * 1.0, 0, gz + 7.6), 1.0, 1.0, 0, {}])

func _static_world() -> void:
	var b := MeshBatch.new()
	var shop := _floor_rect()
	# the shop: a wooden floor a step up, walls from the map, a menu board and flower boxes by the door
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
		# corner posts so the cutaway walls end cleanly
		for p in [shop.position, Vector2(shop.end.x, shop.position.y)]:
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
	for d in demo_objects:
		if d[0] != "farm_plot_01":
			_object(b, d[0], d[1], d[2], d[3], d[4], false)
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
	_add_mesh(b)

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
	if id == "rest_table_small_01":
		for sx in [-1.0, 1.0]:
			seats.append(at + Vector3(sx * (mw * 0.5 + 0.28), 0, 0))

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

func _add_mesh(b: MeshBatch) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not b.is_empty():
		mi.mesh = b.mesh()
	mi.material_override = mat
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
	for d in demo_objects:
		if d[0] == "farm_plot_01":
			Props3D.plot(b, d[1], d[2], d[3], d[5].crop, d[5].stage)
	if dynamic_mesh != null:
		dynamic_mesh.queue_free()
	dynamic_mesh = _add_mesh(b)

# ------------------------------------------------------------------ the cat chef and the guests
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
	var shop := _floor_rect()
	var p := Vector3(randf_range(shop.position.x + 1.0, shop.end.x - 1.0), 0.1, randf_range(shop.position.y + 1.4, shop.position.y + 2.4))
	get_tree().create_timer(randf_range(0.8, 2.5)).timeout.connect(func() -> void:
		if is_instance_valid(chef):
			chef.walk_along([p] as Array[Vector3]))

func _spawn_guest() -> void:
	var free: Array[int] = []
	for i in seats.size():
		if not seat_taken.has(i):
			free.append(i)
	if free.is_empty() or guests.size() >= 4:
		return
	var shop := _floor_rect()
	var si: int = free[randi() % free.size()]
	seat_taken[si] = true
	var seat := seats[si]
	var door := Vector3(shop.position.x + shop.size.x * 0.5, 0.1, shop.position.y)
	var kinds := ["bunny", "bear", "pig", "duck"]
	var shirts := [Color("f09db0"), Color("9ad7bd"), Color("f5d77a"), Color("b9a1e0"), Color("7fb8e0")]
	var a := Animal.new().setup(kinds[randi() % kinds.size()], false, shirts[randi() % shirts.size()])
	a.position = Vector3(door.x + randf_range(-3.0, 3.0), 0.0, 1.0)
	add_child(a)
	guests.append(a)
	var aisle_z := seat.z - 1.0
	var path: Array[Vector3] = [Vector3(door.x, 0.05, door.z - 1.2), Vector3(door.x, 0.1, door.z + 1.2), Vector3(door.x, 0.1, aisle_z), Vector3(seat.x, 0.1, aisle_z), Vector3(seat.x, 0.1, seat.z)]
	a.walk_along(path)
	a.arrived.connect(func() -> void: _guest_seated(a, si, path), CONNECT_ONE_SHOT)

func _guest_seated(a: Animal, si: int, path: Array[Vector3]) -> void:
	a.position.y = 0.2                                             # on the stool
	a.rotation.y = PI * 0.5 if si % 2 == 0 else -PI * 0.5          # seats come in pairs: left of the table faces right, right faces left
	get_tree().create_timer(randf_range(6.0, 11.0)).timeout.connect(func() -> void:
		if not is_instance_valid(a):
			return
		a.position.y = 0.1
		var back: Array[Vector3] = []
		for i in range(path.size() - 2, -1, -1):
			back.append(path[i])
		back.append(Vector3(path[0].x + randf_range(-4.0, 4.0), 0.0, 0.5))
		seat_taken.erase(si)
		a.walk_along(back)
		a.arrived.connect(func() -> void:
			guests.erase(a)
			a.queue_free(), CONNECT_ONE_SHOT))

func _process(delta: float) -> void:
	_crop_timer += delta
	if _crop_timer > 2.0:
		_crop_timer = 0.0
		_dynamic_world()
	_guest_timer -= delta
	if _guest_timer <= 0.0:
		_guest_timer = randf_range(3.0, 6.0)
		_spawn_guest()

# ------------------------------------------------------------------ camera input: drag to move, pinch or wheel to zoom
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
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if pinch_dist > 0.0:
				dist *= pinch_dist / maxf(d, 1.0)
			pinch_dist = d
		else:
			_pan(event.relative)
		_place_camera()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and not DisplayServer.is_touchscreen_available():
		_pan(event.relative)
		_place_camera()
	elif event is InputEventMagnifyGesture:
		dist /= event.factor
		_place_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist /= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
		_place_camera()

func _pan(rel: Vector2) -> void:
	var k := dist / get_viewport().get_visible_rect().size.y * 0.75
	target -= Vector3(rel.x, 0, rel.y / sin(PITCH)) * k

# ------------------------------------------------------------------ overlay
func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = Loc.t("PILOT_3D_TITLE")
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	var hint := Label.new()
	hint.text = Loc.t("PILOT_3D_HINT")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(360, 0)
	box.add_child(hint)
	var back := Button.new()
	back.text = Loc.t("BTN_BACK_2D")
	back.custom_minimum_size = Vector2(0, 56)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world.tscn"))
	box.add_child(back)
