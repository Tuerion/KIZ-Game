extends SceneTree

var ball: Ball


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ball = load("res://content/entities/ball/ball.tscn").instantiate()
	root.add_child(ball)
	ball.freeze = true

	for path in ["start/start", "straight_slope/straight_slope", "curve_left/curve_left"]:
		var section := await _load_section(path)
		var lanes := _lanes(section)
		if path == "start/start":
			if not lanes.is_empty():
				return _fail("start section should have no lane")
		elif lanes.is_empty():
			return _fail("%s has no lane" % path)
		for lane in lanes:
			if lane.ball != ball:
				return _fail("%s lane %s did not get the ball" % [path, lane.name])
		section.free()

	var curve := await _load_section("curve_left/curve_left")
	var curve_lane: DistractionSpawner = _lanes(curve)[0]
	ball.collision_layer = 0
	ball.global_position = curve.to_global(curve_lane.curve.sample_baked(4.0)) + Vector3.UP * 0.5
	var rolling := await _wait_for_spawn(curve_lane, 3.0)
	if rolling == null:
		return _fail("nothing spawned on the curve lane")
	if rolling.progress < 20.0:
		return _fail("spawned only %.1f m up the lane" % rolling.progress)
	await physics_frame
	for mark in rolling.get_node("Warning").get_children():
		if _ground_gap(mark.global_position) > 0.3:
			return _fail("warning mark off the ground at %s" % mark.global_position)
	var frames := 0
	while is_instance_valid(rolling):
		if _ground_gap(rolling.global_position) > 0.6:
			return _fail("rolling distraction left the curve at %s" % rolling.global_position)
		frames += 1
		if frames > 60 * 12:
			return _fail("rolling distraction never reached the entry")
		await physics_frame
	print("ok curve: rolled along the curve and vanished at the entry")
	curve.free()

	ball.global_position = Vector3(7, 20 * 0.2022 + 0.5, -20)
	var straight := await _load_section("straight_slope/straight_slope")
	var straight_lane: DistractionSpawner = _lanes(straight)[0]
	await _wait(2.0)
	if straight_lane.get_child_count() > 0:
		return _fail("spawned while the ball was beside the lane")
	print("ok straight: nothing spawns while the ball is off the lane")

	ball.collision_layer = 2
	ball.global_position = straight.to_global(Vector3(0, 10 * 0.2022 + 0.5, -10))
	var before := ball.distraction_count
	await _wait(10.0)
	if ball.distraction_count <= before:
		return _fail("no rolling distraction stuck to the ball")
	print("ok straight: rolling distraction sticks to the ball")

	print("PASS")
	quit()


func _load_section(path: String) -> Section:
	var section: Section = load("res://content/sections/%s.tscn" % path).instantiate()
	root.add_child(section)
	section.populate(ball, 0.0, 0.0)
	for lane in _lanes(section):
		lane.min_interval = 0.3
		lane.max_interval = 0.3
	for i in 3:
		await physics_frame
	return section


func _lanes(section: Node) -> Array[DistractionSpawner]:
	var lanes: Array[DistractionSpawner] = []
	for child in section.find_children("*", "", true, false):
		if child is DistractionSpawner:
			lanes.append(child)
	return lanes


func _wait_for_spawn(lane: DistractionSpawner, seconds: float) -> RollingDistraction:
	for i in roundi(seconds * 60):
		if lane.get_child_count() > 0:
			return lane.get_child(0)
		await physics_frame
	return null


func _ground_gap(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN * 3, 1)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return point.y - hit.position.y


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
