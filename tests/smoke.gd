extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.coins = 0
	game.served = 0
	game.level = 1
	game.stock.assign([0, 0, 0])
	game.customers.assign([{"seat": 0, "dish": 0, "patience": 45.0, "color": Color.WHITE}])
	game.serve(0)
	assert(game.coins == 0 and game.customers.size() == 1)
	game.start_cooking(0)
	assert(game.cooking == 0)
	game._process(4.0)
	assert(game.stock[0] == 1 and game.cooking == -1)
	game.serve(0)
	assert(game.coins == 18 and game.served == 1 and game.stock[0] == 0)
	game.coins = 60
	game.upgrade()
	assert(game.level == 2 and game.coins == 0)
	game.coins = 77
	game.save_game()
	game.coins = 0
	game.load_game()
	assert(game.coins == 77 and game.level == 2)
	game.customers.assign([{"seat": 0, "dish": 0, "patience": 0.1, "color": Color.WHITE}])
	game.arrival = 100
	game._process(1)
	assert(game.customers.is_empty())
	for i in range(8):
		game.spawn_customer()
	assert(game.customers.size() == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))
	print("PASS: cooking, serving, rewards, upgrade, save/load, patience and capacity")
	quit()
