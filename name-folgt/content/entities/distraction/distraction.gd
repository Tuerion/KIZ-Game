class_name Distraction
extends Area3D

@export var weight := 0.4
@export var growth := 0.04
@export var spin_speed := 2.0
@export var sink := 0.6

@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is Ball:
		set_deferred("monitoring", false)
		body.add_distraction.call_deferred(self)


func stick_to(ball: Ball) -> void:
	var half_size: float = (shape.shape as BoxShape3D).size.x / 2
	var from_ball := (global_position - ball.global_position).normalized()
	global_position = ball.global_position + from_ball * (ball.radius - half_size * sink)
	shape.reparent(ball)
	mesh.reparent(ball)
	queue_free()
