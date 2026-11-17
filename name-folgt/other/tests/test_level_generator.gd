extends SceneTree

const MAX_SECTIONS := 8


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ball_player: Node3D = load("res://content/entities/ball_player/ball_player.tscn").instantiate()
	root.add_child(ball_player)
	var player: Player = ball_player.get_node("Player")
	var ball: Ball = ball_player.get_node("Ball")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	ball.freeze = true

	var generator: LevelGenerator = load("res://content/gameplay/level_generator/level_generator.tscn").instantiate()
	generator.player = player
	generator.ball = ball
	root.add_child(generator)
	await physics_frame

	if generator.placed.size() < 2:
		return _fail("only %d sections built at start" % generator.placed.size())
	var first := generator.placed[0]
	if not first.scene_file_path.ends_with("start.tscn"):
		return _fail("first section is %s, not the start" % first.scene_file_path)
	if player.global_position.distance_to(generator.placed.back().exit.global_position) < generator.build_distance:
		return _fail("did not build ahead to build_distance")

	if not is_equal_approx(generator.distraction_chance(0), 0.25) or not is_equal_approx(generator.distraction_chance(100), 0.35):
		return _fail("distraction chance %.2f / %.2f" % [generator.distraction_chance(0), generator.distraction_chance(100)])
	if not is_equal_approx(generator.distraction_chance(1000), 0.7):
		return _fail("distraction chance not capped: %.2f" % generator.distraction_chance(1000))

	var seen: Array[Section] = []
	var names: Array[String] = []
	for step in 40:
		player.global_position = generator.placed[generator.placed.size() - 2].exit.global_position + Vector3.UP
		for i in 2:
			await physics_frame

		if generator.placed.size() > MAX_SECTIONS:
			return _fail("%d sections alive" % generator.placed.size())
		for i in range(1, generator.placed.size()):
			var before := generator.placed[i - 1]
			var section := generator.placed[i]
			if section.global_position.distance_to(before.exit.global_position) > 0.01:
				return _fail("section %d does not start at the previous exit" % i)
			if section.exit.global_position.y <= before.exit.global_position.y:
				return _fail("section %d does not climb" % i)
		for section in generator.placed:
			if section in seen:
				continue
			seen.append(section)
			names.append(section.scene_file_path.get_file())
			var height := section.global_position.y - generator.start_height
			if height < section.min_height:
				return _fail("%s placed at %.1f m, below its min_height" % [section.scene_file_path.get_file(), height])

	if is_instance_valid(first):
		return _fail("start section never removed")
	var curves := names.slice(names.size() / 2).count("curve_left.tscn")
	if curves == 0:
		return _fail("no curve in the second half of %d sections" % seen.size())
	print("PASS (%d sections placed, %d curves late on, climbed %.0f m)" % [seen.size(), curves, generator.climbed_height()])
	quit()


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
