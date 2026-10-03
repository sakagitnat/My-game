class_name MapStore
extends RefCounted

# Where scene maps come from: the owner's edited copy in user storage if there is one, else the map shipped in
# data/maps. Maps are JSON text (SceneLayout.to_dict), so a finished map can be pasted into a message and
# committed as the new default.
const DEFAULT_DIR := "res://data/maps/"
const USER_DIR := "user://maps/"

static func default_path(scene_id: String) -> String:
	return DEFAULT_DIR + scene_id + ".json"

static func user_path(scene_id: String) -> String:
	return USER_DIR + scene_id + ".json"

static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_string(path))

static func has_user_map(scene_id: String) -> bool:
	return not read_file(user_path(scene_id)).is_empty()

static func load_layout(scene_id: String, use_user_copy: bool = true) -> SceneLayout:
	var d := {}
	if use_user_copy:
		d = read_file(user_path(scene_id))
	if d.is_empty():
		d = read_file(default_path(scene_id))
	if d.is_empty():
		push_error("map %s is missing" % scene_id)
		return SceneLayout.sandbox()
	return SceneLayout.from_dict(d)

static func save_user(layout: SceneLayout) -> bool:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var f := FileAccess.open(user_path(layout.id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_text(layout))
	f.close()
	return true

static func reset_user(scene_id: String) -> void:
	if FileAccess.file_exists(user_path(scene_id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path(scene_id)))

static func to_text(layout: SceneLayout) -> String:
	return JSON.stringify(layout.to_dict())
