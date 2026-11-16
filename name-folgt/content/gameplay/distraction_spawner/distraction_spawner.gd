extends Node3D

@export var distraction_scene: PackedScene
@export var ball: Ball
@export var min_interval := 3.0
@export var max_interval := 6.0
@export var spawn_distance := 25.0
@export var spread := 3.0
@export var half_width := 5.5
@export var top_end := -83.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	_timer = randf_range(min_interval, max_interval)
	_spawn()


func _spawn() -> void:
	var ball_position := to_local(ball.global_position)
	var spawn_position := Vector3(
		clampf(ball_position.x + randf_range(-spread, spread), -half_width, half_width),
		0.2,
		ball_position.z - spawn_distance
	)
	if spawn_position.z < top_end:
		return

	var distraction: Node3D = distraction_scene.instantiate()
	add_child(distraction)
	distraction.position = spawn_position
