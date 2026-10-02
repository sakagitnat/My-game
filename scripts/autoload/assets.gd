extends Node

const DIRS: Array[String] = ["tiles", "restaurant", "buildings", "farm", "deco", "chars", "icons", "ui", "app"]

var _cache: Dictionary = {}

# Returns the AI-made PNG if it exists, otherwise null so callers draw a placeholder.
func get_tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	for d in DIRS:
		var p := "res://assets/%s/%s.png" % [d, id]
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			break
	_cache[id] = tex
	return tex
