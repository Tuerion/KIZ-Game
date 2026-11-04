extends CharacterBody3D

@export var speed := 5.0
@export var acceleration := 25.0
@export var turn_rate := 2.5
@export var camera_height := 1.0
@export var camera_follow := 5.0
@export var camera_pivot: Node3D

func _physics_process(delta):
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	rotation.y -= input.x * turn_rate * delta

	var forward := -global_basis.z
	forward.y = 0
	var target_vel := forward.normalized() * -input.y * speed

	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	
	camera_pivot.global_position = global_position + Vector3.UP * camera_height
