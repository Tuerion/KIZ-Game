extends SceneTree

const WAYPOINTS := {
	"curve_left.tscn": [Vector2(-0.73, -11.2), Vector2(-2.93, -22.24), Vector2(-6.54, -32.9)],
}

var targets: Array[Vector3] = []
var routed: Array[Section] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://main/main.tscn")
	await _wait(0.2)
	var main: Main = current_scene
	var generator: LevelGenerator = main.level.get_node_or_null("LevelGenerator")
	if generator == null:
		return _fail("Main did not load the endless level")
	var player: Player = generator.player
	var ball: Ball = generator.ball
	player.doomscroll_chance = 0.0

	var squashed := [false]
	player.squashed.connect(func() -> void: squashed[0] = true)
	var start_y := ball.global_position.y
	Input.action_press("move_up")
	for frame in 30 * 60:
		_route(generator)
		_steer(ball, player.camera_rig)
		await physics_frame
		if squashed[0]:
			break
	Input.action_release("move_up")
	Input.action_release("move_left")
	Input.action_release("move_right")

	var climbed := ball.global_position.y - start_y
	if squashed[0]:
		return _fail("squashed during the steered run after %.1f m" % climbed)
	if climbed < 10.0:
		return _fail("only climbed %.1f m in 30 s" % climbed)
	if routed.size() < 4:
		return _fail("only %d sections reached" % routed.size())
	print("ok climbed %.1f m over %d sections" % [climbed, routed.size()])

	player.squash()
	await _wait(1.6)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await _wait(0.3)
	var restarted: Main = current_scene
	if restarted == main or restarted == null:
		return _fail("game over did not reload the scene")
	var new_player: Player = restarted.level.get_node("LevelGenerator").player
	if not new_player.can_move:
		return _fail("player cannot move after restart")
	print("PASS")
	quit()


func _route(generator: LevelGenerator) -> void:
	for section in generator.placed:
		if section in routed:
			continue
		routed.append(section)
		for point in WAYPOINTS.get(section.scene_file_path.get_file(), []):
			targets.append(section.to_global(Vector3(point.x, 0, point.y)))
		targets.append(section.exit.global_position)


func _steer(ball: Ball, camera_rig: CameraRig) -> void:
	var to_target := targets[0] - ball.global_position
	to_target.y = 0
	if to_target.length() < 3.0 and targets.size() > 1:
		targets.pop_front()
		return

	var angle := camera_rig.forward.signed_angle_to(to_target, Vector3.UP)
	Input.action_release("move_left")
	Input.action_release("move_right")
	if angle > 0.05:
		Input.action_press("move_left")
	elif angle < -0.05:
		Input.action_press("move_right")


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
