class_name DistractionSpawner
extends Path3D

@export var distraction_scene: PackedScene
@export var ball: Ball
@export var min_interval := 3.0
@export var max_interval := 6.0
@export var spawn_distance := 25.0
@export var spread := 3.0
@export var half_width := 4.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	if ball == null:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_timer = randf_range(min_interval, max_interval)
	_spawn()


func _spawn() -> void:
	var ball_position := to_local(ball.global_position)
	var ball_progress := curve.get_closest_offset(ball_position)
	var lane_point := curve.sample_baked_with_rotation(ball_progress)
	if not _is_on_lane(ball_position, ball_progress, lane_point):
		return

	var ball_side := (ball_position - lane_point.origin).dot(lane_point.basis.x)
	var distraction: RollingDistraction = distraction_scene.instantiate()
	distraction.lane = self
	distraction.progress = minf(ball_progress + spawn_distance, curve.get_baked_length())
	distraction.side = clampf(ball_side + randf_range(-spread, spread), -half_width, half_width)
	add_child(distraction)


func _is_on_lane(ball_position: Vector3, ball_progress: float, lane_point: Transform3D) -> bool:
	var inside := ball_progress > 0.0 and ball_progress < curve.get_baked_length()
	return inside and ball_position.distance_to(lane_point.origin) <= half_width + 2.0
