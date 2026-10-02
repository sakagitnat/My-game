class_name Inventory
extends RefCounted

var items: Dictionary = {}
var capacity: int = 50

func _init(cap: int = 50) -> void:
	capacity = cap

func count(id: String) -> int:
	return int(items.get(id, 0))

func total() -> int:
	var t := 0
	for id in items:
		t += int(items[id])
	return t

func space_left() -> int:
	return maxi(0, capacity - total())

func add(id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var added := mini(amount, space_left())
	if added > 0:
		items[id] = count(id) + added
	return added

func remove(id: String, amount: int) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	var left := count(id) - amount
	if left == 0:
		items.erase(id)
	else:
		items[id] = left
	return true

func to_dict() -> Dictionary:
	return {"items": items.duplicate(), "capacity": capacity}

func load_dict(d: Dictionary) -> void:
	capacity = maxi(1, int(d.get("capacity", capacity)))
	items.clear()
	var src = d.get("items", {})
	if src is Dictionary:
		for id in src:
			var n := int(src[id])
			if n > 0:
				items[str(id)] = n
