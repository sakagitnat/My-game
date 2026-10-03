extends SceneTree

# Validates art dropped into assets/ against docs/ASSETS.md so both sides get instant feedback.
const SQUARE_1024 := ["tiles", "restaurant", "farm", "buildings", "deco", "chars", "obstacles"]
const NAME_RE := "^[a-z0-9_]+\\.png$"

var problems: Array[String] = []
var checked := 0

func _initialize() -> void:
	var re := RegEx.create_from_string(NAME_RE)
	var root_dir := DirAccess.open("res://assets")
	for sub in root_dir.get_directories():
		var dir := DirAccess.open("res://assets/" + sub)
		for f in dir.get_files():
			if not f.ends_with(".png"):
				continue
			checked += 1
			var path := "res://assets/%s/%s" % [sub, f]
			if re.search(f) == null:
				problems.append("%s: file name must be lowercase letters, digits and underscores" % path)
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				problems.append("%s: cannot be read as an image" % path)
				continue
			if sub in SQUARE_1024:
				if img.get_width() != 1024 or img.get_height() != 1024:
					problems.append("%s: must be 1024x1024, is %dx%d" % [path, img.get_width(), img.get_height()])
					continue
				for corner in [Vector2i(0, 0), Vector2i(1023, 0), Vector2i(0, 1023), Vector2i(1023, 1023)]:
					if img.get_pixelv(corner).a > 0.02:
						problems.append("%s: corners must be transparent (background not removed?)" % path)
						break
				if img.get_used_rect().size.x < 128:
					problems.append("%s: artwork is almost empty or tiny" % path)
			elif sub == "walls":
				var low := f.begins_with("wall_low")
				var want := Vector2i(256, 840) if f.begins_with("wdeco_") else Vector2i(512, 112 if low else 840)
				if img.get_size() != want:
					problems.append("%s: wall pieces must be %dx%d, are %dx%d" % [path, want.x, want.y, img.get_width(), img.get_height()])
			elif sub == "icons":
				if img.get_width() != 256 or img.get_height() != 256:
					problems.append("%s: icons must be 256x256, are %dx%d" % [path, img.get_width(), img.get_height()])
	if problems.is_empty():
		print("PASS: %d art files follow docs/ASSETS.md" % checked)
		quit(0)
	else:
		for p in problems:
			printerr("ART PROBLEM: ", p)
		quit(1)
