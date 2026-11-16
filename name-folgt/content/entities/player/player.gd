extends CharacterBody3D

signal squashed

enum State { WALKING, BUZZING, ON_PHONE, SQUASHED }

@export var speed := 5.0
@export var acceleration := 25.0
@export var turn_speed := 10.0
@export var hold_distance := 0.9
@export var grip_range := 1.3
@export var grip_stiffness := 40.0
@export var grip_damping := 10.0
@export var camera_height := 1.0
@export var camera_follow := 5.0

@export_group("Doomscroll")
@export var doomscroll_threshold := 3
@export var check_interval := 4.0
@export var buzz_time := 0.8
@export var base_duration := 1.5
@export var duration_per_distraction := 0.5
@export var shove_speed := 3.0

@export_group("Ball Hit")
@export var hit_reach := 0.75
@export var hit_speed := 1.5
@export var squash_impact := 9.0
@export var knockback_speed := 6.0
@export var stun_time := 0.5

@export_group("Nodes")
@export var camera_pivot: Node3D
@export var ball: Ball
@export var phone: Phone

var _state := State.WALKING
var _check_timer := 0.0
var _stun_timer := 0.0

@onready var _body_mesh: MeshInstance3D = $MeshInstance3D
@onready var _hand_phone: MeshInstance3D = $MeshInstance3D/HandPhone


func _ready() -> void:
	phone.closed.connect(_on_phone_closed)


func _physics_process(delta: float) -> void:
	if _state == State.SQUASHED:
		return

	_stun_timer = maxf(_stun_timer - delta, 0.0)
	var direction := _input_direction()

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)

	var walk_velocity := velocity
	move_and_slide()
	if _state != State.ON_PHONE:
		_grip_ball(direction, walk_velocity)

	_check_ball_hit()
	_update_doomscroll(delta)

	var camera_target := global_position + Vector3.UP * camera_height
	camera_pivot.global_position = camera_pivot.global_position.lerp(camera_target, camera_follow * delta)


func _input_direction() -> Vector3:
	if _state == State.ON_PHONE or _stun_timer > 0.0:
		return Vector3.ZERO

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := camera_pivot.global_basis * Vector3(input.x, 0, input.y)
	direction.y = 0
	return direction.normalized()


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


func _update_doomscroll(delta: float) -> void:
	if _state != State.WALKING:
		return

	_check_timer += delta
	if _check_timer < check_interval:
		return

	_check_timer = 0.0
	if ball.distraction_count >= doomscroll_threshold:
		_start_buzzing()


func _start_buzzing() -> void:
	_state = State.BUZZING
	_hand_phone.show()

	var buzz := create_tween().set_loops(roundi(buzz_time / 0.1))
	buzz.tween_property(_hand_phone, "rotation:z", 0.25, 0.05)
	buzz.tween_property(_hand_phone, "rotation:z", -0.25, 0.05)
	buzz.finished.connect(_take_out_phone)


func _take_out_phone() -> void:
	if _state != State.BUZZING:
		return

	_state = State.ON_PHONE
	_hand_phone.rotation.z = 0.0
	ball.focused = false
	_shove_ball()
	phone.open(base_duration + duration_per_distraction * ball.distraction_count)


func _shove_ball() -> void:
	var lean := create_tween()
	lean.tween_property(_body_mesh, "rotation:x", -0.4, 0.08)
	lean.tween_property(_body_mesh, "rotation:x", -0.2, 0.3)

	var to_ball := ball.global_position - global_position
	to_ball.y = 0
	if to_ball.length() > grip_range + ball.radius:
		return
	var ball_velocity := ball.linear_velocity
	ball_velocity.y = 0
	var shove_velocity := to_ball.normalized() * shove_speed
	ball.apply_central_impulse((shove_velocity - ball_velocity) * ball.mass)


func _on_phone_closed() -> void:
	if _state != State.ON_PHONE:
		return

	_state = State.WALKING
	ball.focused = true
	_hand_phone.hide()
	create_tween().tween_property(_body_mesh, "rotation:x", 0.0, 0.2)


func _check_ball_hit() -> void:
	if _stun_timer > 0.0:
		return

	var from_ball := global_position - ball.global_position
	from_ball.y = 0
	if from_ball.length() > ball.radius + hit_reach:
		return

	var closing_speed := ball.linear_velocity.dot(from_ball.normalized())
	if closing_speed < hit_speed:
		return

	if ball.mass * closing_speed >= squash_impact:
		_get_squashed()
	else:
		velocity = from_ball.normalized() * knockback_speed
		_stun_timer = stun_time


func _get_squashed() -> void:
	_state = State.SQUASHED
	velocity = Vector3.ZERO
	_hand_phone.hide()
	ball.focused = true
	$CollisionShape3D.set_deferred("disabled", true)
	if phone.visible:
		phone.close()

	var flatten := create_tween().set_parallel()
	flatten.tween_property(_body_mesh, "rotation:x", 0.0, 0.1)
	flatten.tween_property(_body_mesh, "scale", Vector3(1.5, 0.15, 1.5), 0.12)
	flatten.tween_property(_body_mesh, "position:y", -0.85, 0.12)
	squashed.emit()
