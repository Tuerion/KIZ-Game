extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load("res://content/levels/prototype/prototype_level.tscn").instantiate()
	root.add_child(level)
	var player: Player = level.get_node("BallPlayer/Player")
	player.doomscroll_threshold = 1000
	var spawner: DistractionSpawner = level.get_node("DistractionSpawner")
	var spawned := 0
	var known := {}
	Input.action_press("move_up")
	for frame in 60 * 20:
		await physics_frame
		for child in spawner.get_children():
			if not known.has(child):
				known[child] = true
				spawned += 1
	if spawned == 0:
		print("FAIL: no rolling distraction spawned in 20 s")
		quit(1)
		return
	print("PASS (%d spawned)" % spawned)
	quit()
