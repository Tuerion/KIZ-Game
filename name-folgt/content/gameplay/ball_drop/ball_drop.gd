class_name BallDrop
extends Node

@export var ball: Ball
@export var player: Player
@export var fall_depth := 4.0
@export var drop_height := 10.0
@export var drop_speed := 12.0

var _last_ground_y := 0.0
var _dropping := false


func _ready() -> void:
	_last_ground_y = ball.global_position.y


func _physics_process(delta: float) -> void:
	if _dropping:
		_move_drop(delta)
		return

	_track_ground()
	if ball.global_position.y < _last_ground_y - fall_depth:
		_on_ball_fell()


func _track_ground() -> void:
	var from := ball.global_position
	var to := from + Vector3.DOWN * (ball.radius + 0.5)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := ball.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_last_ground_y = hit.position.y


func _on_ball_fell() -> void:
	_drop_on_player()


func _drop_on_player() -> void:
	_dropping = true
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.freeze = true
	ball.global_position = player.global_position + Vector3.UP * drop_height


func _move_drop(delta: float) -> void:
	var target := player.global_position
	ball.global_position = Vector3(target.x, ball.global_position.y - drop_speed * delta, target.z)
	if ball.global_position.y - ball.radius > target.y + 0.5:
		return

	_dropping = false
	player.squash()
	ball.freeze = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_last_ground_y = ball.global_position.y
