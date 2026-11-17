class_name Player
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
@export var orbit_follow := 8.0
@export var edge_margin := 0.4
@export var edge_depth := 1.5

@export_group("Doomscroll")
@export var doomscroll_threshold := 3
@export_range(0.0, 1.0) var doomscroll_chance := 0.4
@export var check_interval := 4.0
@export var buzz_time := 0.8
@export var base_duration := 1.5
@export var duration_per_distraction := 0.5
@export var shove_speed := 7.0
@export var return_steering := 4.0
@export var unstick_speed := 0.5
@export var unstick_push := 3.0

@export_group("Ball Hit")
@export var hit_reach := 0.4
@export var hit_speed := 1.5
@export var squash_impact := 9.0
@export var knockback_speed := 6.0
@export var stun_time := 0.5

@export_group("Nodes")
@export var camera_rig: CameraRig
@export var ball: Ball
@export var phone: Phone

var is_holding_ball := false

var can_move: bool:
	get:
		return (_state == State.WALKING or _state == State.BUZZING) and _stun_timer <= 0.0

var _state := State.WALKING
var _ball_returning := false
var _check_timer := 0.0
var _stun_timer := 0.0

@onready var _capsule: CapsuleShape3D = $CollisionShape3D.shape
@onready var _body_mesh: MeshInstance3D = $MeshInstance3D
@onready var _hand_phone: MeshInstance3D = $MeshInstance3D/HandPhone


func _ready() -> void:
	phone.closed.connect(_on_phone_closed)


func _physics_process(delta: float) -> void:
	if _state == State.SQUASHED:
		return

	_stun_timer = maxf(_stun_timer - delta, 0.0)
	var direction := _input_direction()
	var target_velocity := direction * speed
	if is_holding_ball:
		target_velocity += _to_spot_behind_ball() * orbit_follow
	target_velocity = target_velocity.limit_length(speed)

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not _has_ground_ahead(delta):
		velocity.x = 0.0
		velocity.z = 0.0

	if can_move:
		rotation.y = lerp_angle(rotation.y, camera_rig.yaw, turn_speed * delta)

	var walk_velocity := velocity
	move_and_slide()
	is_holding_ball = _state != State.ON_PHONE and _grip_ball(walk_velocity)
	if _ball_returning:
		_steer_ball_back()

	_check_ball_hit()
	_update_doomscroll(delta)


func _input_direction() -> Vector3:
	if not can_move:
		return Vector3.ZERO
	return camera_rig.forward * Input.get_action_strength("move_up")


func _has_ground_ahead(delta: float) -> bool:
	var flat_velocity := velocity.slide(Vector3.UP)
	if flat_velocity.is_zero_approx():
		return true

	var feet := global_position + Vector3.DOWN * _capsule.height / 2
	var ahead := feet + flat_velocity.normalized() * (edge_margin + flat_velocity.length() * delta)
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * edge_depth, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _to_spot_behind_ball() -> Vector3:
	var spot := ball.global_position - camera_rig.forward * (hold_distance + ball.radius)
	return (spot - global_position).slide(Vector3.UP)


func _grip_ball(walk_velocity: Vector3) -> bool:
	var to_ball := ball.global_position - global_position
	if to_ball.length() > grip_range + ball.radius:
		return false

	var forward := -global_basis.z
	var offset := global_position + forward * (hold_distance + ball.radius) - ball.global_position
	var push_velocity := forward * walk_velocity.dot(forward)
	var force := offset * grip_stiffness + (push_velocity - ball.linear_velocity) * grip_damping
	force.y = 0
	ball.apply_central_force(force)
	return true


func _steer_ball_back() -> void:
	if is_holding_ball:
		_ball_returning = false
		return

	var aim := (global_position - ball.global_position).slide(Vector3.UP).normalized()
	var flat_velocity := ball.linear_velocity.slide(Vector3.UP)
	var sideways := flat_velocity.slide(aim)
	ball.apply_central_force(-sideways * return_steering * ball.mass)
	if flat_velocity.length() < unstick_speed:
		ball.apply_central_force(aim * unstick_push * ball.mass)


func _update_doomscroll(delta: float) -> void:
	if _state != State.WALKING or not is_holding_ball:
		return

	_check_timer += delta
	if _check_timer < check_interval:
		return

	_check_timer = 0.0
	if ball.distraction_count >= doomscroll_threshold and randf() < doomscroll_chance:
		_start_buzzing()


func _start_buzzing() -> void:
	_state = State.BUZZING
	phone.buzz(buzz_time)
	create_tween().tween_callback(_take_out_phone).set_delay(buzz_time)


func _take_out_phone() -> void:
	if _state != State.BUZZING:
		return

	_state = State.ON_PHONE
	_hand_phone.show()
	ball.focused = false
	_shove_ball()
	phone.open(base_duration + duration_per_distraction * ball.distraction_count)


func _shove_ball() -> void:
	var lean := create_tween()
	lean.tween_property(_body_mesh, "rotation:x", -0.4, 0.08)
	lean.tween_property(_body_mesh, "rotation:x", -0.2, 0.3)

	if not is_holding_ball:
		return
	var to_ball := (ball.global_position - global_position).slide(Vector3.UP)
	var shove_velocity := to_ball.normalized() * shove_speed
	ball.apply_central_impulse((shove_velocity - ball.linear_velocity.slide(Vector3.UP)) * ball.mass)
	ball.angular_velocity = Vector3.UP.cross(shove_velocity) / ball.radius
	_ball_returning = true


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

	var from_ball := (global_position - ball.global_position).slide(Vector3.UP)
	if from_ball.length() > ball.radius + hit_reach:
		return

	var closing_speed := ball.linear_velocity.dot(from_ball.normalized())
	if closing_speed < hit_speed:
		return

	_ball_returning = false
	if ball.mass * closing_speed >= squash_impact:
		squash()
	else:
		velocity = from_ball.normalized() * knockback_speed
		_stun_timer = stun_time


func squash() -> void:
	if _state == State.SQUASHED:
		return

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
	flatten.tween_property(_body_mesh, "position:y", -0.42, 0.12)
	squashed.emit()
