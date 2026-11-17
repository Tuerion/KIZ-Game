class_name CameraRig
extends Node3D

@export var turn_speed := 2.0
@export var auto_turn_speed := 3.0
@export var height := 0.3
@export var follow_speed := 6.0
@export var offset := Vector3(0, 1.8, 4.5)
@export var look_ahead := 2.0
@export var zoom_per_radius := 0.5

@export_group("Nodes")
@export var player: Player
@export var ball: Ball

var yaw := 0.0

var forward: Vector3:
	get:
		return Vector3.FORWARD.rotated(Vector3.UP, yaw)

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	yaw = player.rotation.y
	global_position = _target_position()


func _physics_process(delta: float) -> void:
	var turn := Input.get_axis("move_right", "move_left")
	if player.can_move and turn != 0.0:
		yaw += turn * turn_speed * delta
	elif not player.is_holding_ball:
		yaw = lerp_angle(yaw, _yaw_to_ball(), auto_turn_speed * delta)

	global_position = global_position.lerp(_target_position(), follow_speed * delta)
	rotation.y = yaw
	_camera.position = offset * (1.0 + ball.radius * zoom_per_radius)
	_camera.look_at(global_position + forward * look_ahead)


func _target_position() -> Vector3:
	return player.global_position + Vector3.UP * height


func _yaw_to_ball() -> float:
	var to_ball := ball.global_position - player.global_position
	return atan2(-to_ball.x, -to_ball.z)
