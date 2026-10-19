extends SceneTree
# Screenshots of the 3D preview (scenes/world3d.tscn) on a new game, so the sample shop and garden show:
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --script tools/screenshot/shot3d.gd -- OUTDIR
# Each view: camera target (x, z) in cells and distance.

const VIEWS := {
	"overview": [Vector2(24, 15), 30.0],
	"shop": [Vector2(18, 11), 13.0],
	"garden": [Vector2(34, 11), 13.0],
	"beach": [Vector2(17, 27), 16.0],
	"chef": [Vector2(16, 8), 4.0],
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var out := "shots3d"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var gs = root.get_node("/root/GameState")
	gs.ask_names = false
	gs.autosave = false
	gs.save_path = "user://screenshot_salvora3d.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()
	var world = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(world)
	for i in 240:                                       # let the chef and a few guests walk in
		await process_frame
	for name in VIEWS:
		var v: Array = VIEWS[name]
		world.target = Vector3(v[0].x, 0, v[0].y)
		if name == "chef" and world.chef != null:             # follow the cat chef, seen from the front
			world.chef.path.clear()
			world.chef.rotation.y = 0.0
			world.target = world.chef.position + Vector3(0, 0.5, 0)
		world.dist = float(v[1])
		world._place_camera()
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("saved ", name)
	quit()
