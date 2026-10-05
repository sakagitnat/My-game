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

	_check_topdown()
	if problems.is_empty():
		print("PASS: %d art files follow docs/ASSETS.md" % checked)
		quit(0)
	else:
		for p in problems:
			printerr("ART PROBLEM: ", p)
		quit(1)

# Top-down art (docs/ART_TOPDOWN.md): pixel art in assets/td/<folder>/*.png, one cell = 32 px (shown at 2x).
func _check_topdown() -> void:
	var re := RegEx.create_from_string(NAME_RE)
	var base := DirAccess.open("res://assets/td")
	if base == null:
		return
	for sub in base.get_directories():
		if sub == "art_workshop":
			continue   # drawing tool for the owner, not game art
		var dir := DirAccess.open("res://assets/td/" + sub)
		for f in dir.get_files():
			if not f.ends_with(".png"):
				continue
			checked += 1
			var path := "res://assets/td/%s/%s" % [sub, f]
			if re.search(f) == null:
				problems.append("%s: file name must be lowercase letters, digits and underscores" % path)
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				problems.append("%s: cannot be read as an image" % path)
				continue
			var want := Vector2i.ZERO
			if sub == "tiles" or sub == "icons":
				want = Vector2i(32, 32)
			elif sub == "props":
				want = Vector2i(16, 16)
			elif sub == "walls":
				if f.begins_with("wdeco_door"):
					want = Vector2i(32, 70)   # two blocks (64 px) above the base line (6 px up from the bottom) plus the 6 px below it
				elif f.begins_with("wdeco_"):
					want = Vector2i(32, 32)
				elif f.begins_with("wall_low"):
					want = Vector2i(32, 16)
				elif f.begins_with("wall_side"):
					want = Vector2i(12, 96)
				else:
					want = Vector2i(32, 96)   # a wall is three blocks tall
			if want != Vector2i.ZERO:
				if img.get_size() != want:
					problems.append("%s: must be %dx%d, is %dx%d" % [path, want.x, want.y, img.get_width(), img.get_height()])
			elif img.get_width() % 16 != 0 or img.get_height() % 8 != 0:
				problems.append("%s: width must be whole units (multiple of 16 = half a cell) and height a multiple of 8, is %dx%d" % [path, img.get_width(), img.get_height()])
			if sub != "tiles" and img.get_used_rect().size.x < 4:
				problems.append("%s: artwork is almost empty" % path)
