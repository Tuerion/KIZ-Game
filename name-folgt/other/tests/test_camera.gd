extends SceneTree

var level: Node
var player: Player
var ball: Ball
var rig: CameraRig
var phone: Phone


func _initialize() -> void:
	_run.call_deferred()


func _load() -> void:
	if level:
		level.free()
	level = load("res://content/levels/prototype/prototype_level.tscn").instantiate()
	for child_name in ["Distractions", "FocusBalls", "DistractionSpawner"]:
		var node := level.get_node_or_null(child_name)
		if node:
			node.free()
	root.add_child(level)
	player = level.get_node("BallPlayer/Player")
	ball = level.get_node("BallPlayer/Ball")
	rig = level.get_node("BallPlayer/CameraRig")
	phone = level.get_node("BallPlayer/Phone")


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _flat_distance() -> float:
	var d := ball.global_position - player.global_position
	d.y = 0
	return d.length()


func _release_all() -> void:
	for action in ["move_up", "move_left", "move_right"]:
		Input.action_release(action)


func _run() -> void:
	await _test_push_and_turn()
	for count in [3, 5, 7]:
		for close_mode in ["stand", "never"]:
			var results := {}
			for trial in 4:
				var outcome: String = await _test_doomscroll(count, close_mode, trial)
				results[trial] = outcome
			print("count=%d close=%s -> %s" % [count, close_mode, results])
	quit()


func _test_push_and_turn() -> void:
	_load()
	await _wait(0.5)
	Input.action_press("move_up")
	await _wait(3.0)
	print("push: player z=%.1f ball dist=%.2f holding=%s ball speed=%.2f" % [player.global_position.z, _flat_distance(), player.is_holding_ball, ball.linear_velocity.length()])
	Input.action_release("move_up")
	await _wait(1.0)
	var ball_start := ball.global_position
	var yaw_start := rig.yaw
	Input.action_press("move_left")
	for i in 6:
		await _wait(0.25)
		print("  turn t=%.2f yaw=%.0f deg dist=%.2f holding=%s ball moved=%.2f" % [(i + 1) * 0.25, rad_to_deg(rig.yaw - yaw_start), _flat_distance(), player.is_holding_ball, ball.global_position.distance_to(ball_start)])
	Input.action_release("move_left")
	await _wait(0.5)
	Input.action_press("move_up")
	await _wait(1.5)
	Input.action_release("move_up")
	print("after turn+push: dist=%.2f holding=%s ball moved=%.2f" % [_flat_distance(), player.is_holding_ball, ball.global_position.distance_to(ball_start)])


func _test_doomscroll(count: int, close_mode: String, trial: int) -> String:
	_load()
	seed(trial * 31 + count)
	await _wait(0.5)
	Input.action_press("move_up")
	await _wait(3.5)
	Input.action_release("move_up")
	await _wait(0.3)

	var distraction_scene: PackedScene = load("res://content/entities/distraction/distraction.tscn")
	for i in count:
		var distraction: Distraction = distraction_scene.instantiate()
		level.add_child(distraction)
		var direction := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		distraction.global_position = ball.global_position + direction * ball.radius
		ball.add_distraction(distraction)
		await physics_frame

	player._check_timer = 0.0
	player._start_buzzing()
	var phone_time := player.base_duration + player.duration_per_distraction * count
	var elapsed := 0.0
	var closed := false
	while elapsed < 10.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		if not closed and close_mode != "never" and elapsed > player.buzz_time + phone_time + 0.5:
			phone.close()
			closed = true
			if close_mode == "walk":
				Input.action_press("move_up")
		if player._state == player.State.SQUASHED:
			_release_all()
			return "squashed@%.1f%s" % [elapsed, "c" if closed else "p"]
		if player._stun_timer > 0.0:
			_release_all()
			return "hit@%.1f%s w%.1f" % [elapsed, "c" if closed else "p", ball.mass * ball.linear_velocity.length()]
		if closed and player.is_holding_ball:
			_release_all()
			return "caught@%.1f" % elapsed
		if ball.global_position.z > player.global_position.z + 3.0:
			_release_all()
			return "missed"
	_release_all()
	return "none d%.1f v%.1f" % [_flat_distance(), ball.linear_velocity.length()]
