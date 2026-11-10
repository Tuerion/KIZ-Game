extends CharacterBody3D

@export var speed := 5.0
@export var acceleration := 25.0
@export var turn_speed := 10.0
@export var hold_distance := 0.9
@export var grip_range := 1.3
@export var grip_stiffness := 40.0
@export var grip_damping := 10.0
@export var camera_height := 1.0
@export var camera_follow := 5.0
@export var camera_pivot: Node3D
@export var ball: Ball


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := camera_pivot.global_basis * Vector3(input.x, 0, input.y)
	direction.y = 0
	direction = direction.normalized()

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)

	var walk_velocity := velocity
	move_and_slide()
	_grip_ball(direction, walk_velocity)

	var camera_target := global_position + Vector3.UP * camera_height
	camera_pivot.global_position = camera_pivot.global_position.lerp(camera_target, camera_follow * delta)


func _grip_ball(direction: Vector3, walk_velocity: Vector3) -> void:
	var to_ball := ball.global_position - global_position
	if to_ball.length() > grip_range + ball.radius:
		return

	to_ball.y = 0
	if direction.dot(to_ball.normalized()) < -0.5:
		return

	var forward := -global_basis.z
	var offset := global_position + forward * (hold_distance + ball.radius) - ball.global_position
	var velocity_difference := walk_velocity - ball.linear_velocity
	var force := offset * grip_stiffness + velocity_difference * grip_damping
	force.y = 0
	ball.apply_central_force(force)
