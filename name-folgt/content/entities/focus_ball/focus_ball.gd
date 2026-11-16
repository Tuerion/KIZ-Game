class_name FocusBall
extends Area3D

@export var bob_height := 0.12
@export var bob_speed := 2.0

var _time := 0.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_mesh.position.y = sin(_time * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if body is Ball:
		set_deferred("monitoring", false)
		body.remove_distraction.call_deferred()
		_vanish()


func _vanish() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_mesh, "scale", Vector3.ONE * 1.8, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_mesh, "transparency", 1.0, 0.35)
	tween.chain().tween_callback(queue_free)
