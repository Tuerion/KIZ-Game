extends SceneTree

var world: Node3D
var player: Player
var ball: Ball
var drop: BallDrop
var was_squashed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_world()
	Input.action_press("move_up")
	await _wait(3.0)
	Input.action_release("move_up")
	if was_squashed or ball.freeze:
		return _fail("dropped while pushing normally")
	print("ok normal pushing")

	_build_world()
	ball.global_position = Vector3(8, 1, 0)
	await _wait(4.0)
	if not was_squashed:
		return _fail("ball fell off but player was not squashed")
	print("ok fall off")

	_build_world()
	ball.global_position = Vector3(8, 1, 0)
	await _wait_until(func() -> bool: return ball.freeze, 3.0)
	if not ball.freeze:
		return _fail("drop never started")
	player.global_position += Vector3(-2, 0, 3)
	await _wait(2.0)
	if not was_squashed:
		return _fail("player escaped the drop by walking away")
	print("ok walking away")

	_build_world()
	player.phone.open(10.0)
	player._state = Player.State.ON_PHONE
	ball.global_position = Vector3(8, 1, 0)
	await _wait(4.0)
	if not was_squashed or player.phone.visible:
		return _fail("on phone: squashed %s, phone visible %s" % [was_squashed, player.phone.visible])
	if ball.freeze:
		return _fail("ball still frozen after the drop")
	print("ok on phone")

	print("PASS")
	quit()


func _build_world() -> void:
	if world:
		world.free()
	world = Node3D.new()
	root.add_child(world)
	was_squashed = false

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(10, 1, 60)
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, -25)
	world.add_child(floor_body)

	var ball_player: Node3D = load("res://content/entities/ball_player/ball_player.tscn").instantiate()
	world.add_child(ball_player)
	player = ball_player.get_node("Player")
	ball = ball_player.get_node("Ball")
	player.global_position = Vector3(0, 0.6, 2)
	ball.global_position = Vector3(0, 0.5, 0.5)
	player.squashed.connect(func() -> void: was_squashed = true)
	ball_player.get_node("GameOver").process_mode = Node.PROCESS_MODE_DISABLED

	drop = load("res://content/gameplay/ball_drop/ball_drop.tscn").instantiate()
	drop.ball = ball
	drop.player = player
	world.add_child(drop)


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _wait_until(condition: Callable, seconds: float) -> void:
	for i in roundi(seconds * 60):
		if condition.call():
			return
		await physics_frame


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
