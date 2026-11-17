extends SceneTree

var level: Node
var player: Player
var ball: Ball
var phone: Phone


func _initialize() -> void:
	_run.call_deferred()


func _load() -> void:
	if level:
		level.free()
	level = load("res://content/levels/prototype/prototype_level.tscn").instantiate()
	for child_name in ["Distractions", "FocusBalls", "DistractionSpawner"]:
		level.get_node(child_name).free()
	root.add_child(level)
	player = level.get_node("BallPlayer/Player")
	ball = level.get_node("BallPlayer/Ball")
	phone = level.get_node("BallPlayer/Phone")


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _flat_distance() -> float:
	var d := ball.global_position - player.global_position
	d.y = 0
	return d.length()


func _run() -> void:
	for mode in ["never", "close", "flat"]:
		for count in [3, 5, 7]:
			var results := []
			for trial in 4:
				results.append(await _trial(count, trial, mode))
			print("%s count=%d -> %s" % [mode, count, results])
	quit()


func player_default_shove() -> float:
	return -1.0


func _trial(count: int, trial: int, mode: String) -> String:
	_load()
	seed(trial * 31 + count)
	await _wait(0.5)
	if mode != "flat":
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
	var elapsed := 0.0
	var max_distance := 0.0
	var still_time := 0.0
	var phone_time := player.buzz_time + player.base_duration + player.duration_per_distraction * count + 0.5
	var closed := false
	while elapsed < 16.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		if mode != "never" and not closed and elapsed > phone_time:
			phone.close()
			closed = true
		if closed and player.is_holding_ball and elapsed > phone_time + 0.1:
			return "caught@%.1f max%.1f" % [elapsed, max_distance]
		max_distance = maxf(max_distance, _flat_distance())
		if elapsed > 1.5 and ball.linear_velocity.length() < 0.05 and _flat_distance() > ball.radius + 1.5:
			still_time += 1.0 / 60.0
		else:
			still_time = 0.0
		if still_time > 1.5:
			return "STUCK d%.1f sleep=%s" % [_flat_distance(), ball.sleeping]
		if player._state == player.State.SQUASHED:
			return "squash@%.1f max%.1f" % [elapsed, max_distance]
		if player._stun_timer > 0.0:
			return "hit@%.1f max%.1f w%.1f" % [elapsed, max_distance, ball.mass * ball.linear_velocity.length()]
	return "none d%.1f" % _flat_distance()
