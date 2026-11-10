class_name Distraction
extends Area3D

@export var weight := 0.4
@export var growth := 0.04
@export var spin_speed := 2.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is Ball:
		body.add_distraction.call_deferred(self)


func stick_to(ball: Ball) -> void:
	var from_ball := (global_position - ball.global_position).normalized()
	global_position = ball.global_position + from_ball * ball.radius
	for child in get_children():
		child.reparent(ball)
	queue_free()
