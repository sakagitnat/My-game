class_name SaveStore
extends RefCounted

const VERSION := 1

static func write(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var body := data.duplicate()
	body["version"] = VERSION
	f.store_string(JSON.stringify(body))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed = json.data
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
		return parsed
	return {}
