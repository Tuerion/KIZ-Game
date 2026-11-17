extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ball: Ball = load("res://content/entities/ball/ball.tscn").instantiate()
	root.add_child(ball)
	ball.freeze = true
	await process_frame

	var start_radius := ball.radius
	var start_mass := ball.mass
	for i in 3:
		var distraction: Distraction = load("res://content/entities/distraction/distraction.tscn").instantiate()
		root.add_child(distraction)
		distraction.global_position = ball.global_position + Vector3.RIGHT * ball.radius
		await process_frame
		ball.add_distraction(distraction)
	var grown_radius := ball.radius
	if grown_radius <= start_radius:
		return _fail("ball did not grow")

	for i in 3:
		ball.remove_distraction()
	await process_frame
	if not is_equal_approx(ball.radius, grown_radius):
		return _fail("ball shrank from %.3f to %.3f" % [grown_radius, ball.radius])
	if ball.distraction_count != 0:
		return _fail("%d distractions still stuck" % ball.distraction_count)
	if not is_equal_approx(ball.mass, start_mass):
		return _fail("weight not removed: mass %.2f, expected %.2f" % [ball.mass, start_mass])

	print("PASS (radius stays %.2f)" % ball.radius)
	quit()


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
