extends SceneTree

var world: Node3D
var player: Player
var ball: Ball


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _build(30.0)
	Input.action_press("move_up")
	await _wait(4.0)
	Input.action_release("move_up")
	if not _on_platform():
		return _fail("walked off the edge (z=%.2f y=%.2f)" % [player.global_position.z, player.global_position.y])

	await _build(30.0)
	player.global_position = Vector3(0, 0.5, -2.0)
	await _wait(0.2)
	player.velocity = Vector3(0, 0, -8)
	player._stun_timer = 0.5
	await _wait(1.5)
	if not _on_platform():
		return _fail("knockback pushed player off (z=%.2f y=%.2f)" % [player.global_position.z, player.global_position.y])

	await _build(1.5)
	Input.action_press("move_up")
	await _wait(4.0)
	Input.action_release("move_up")
	if not _on_platform():
		return _fail("fell into the gap (z=%.2f y=%.2f)" % [player.global_position.z, player.global_position.y])

	print("PASS")
	quit()


func _build(gap: float) -> void:
	if world:
		world.free()
	world = Node3D.new()
	root.add_child(world)
	_add_platform(Vector3(0, -0.5, 0), Vector3(6, 1, 6))
	_add_platform(Vector3(0, -0.5, -3.0 - gap - 3.0), Vector3(6, 1, 6))

	var ball_player: Node3D = load("res://content/entities/ball_player/ball_player.tscn").instantiate()
	world.add_child(ball_player)
	player = ball_player.get_node("Player")
	ball = ball_player.get_node("Ball")
	player.doomscroll_threshold = 1000
	player.global_position = Vector3(0, 0.5, 1.5)
	ball.global_position = Vector3(0, 0.6, -3.0 - gap - 3.0)
	await _wait(0.3)


func _add_platform(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = center


func _on_platform() -> bool:
	return player.global_position.z > -3.0 and player.global_position.y > 0.4


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
