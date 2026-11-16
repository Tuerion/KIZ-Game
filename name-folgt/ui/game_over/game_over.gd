extends CanvasLayer

@export var delay := 0.8

var _can_restart := false

@onready var _root: Control = $Root


func _input(event: InputEvent) -> void:
	if not _can_restart:
		return

	var tapped: bool = event is InputEventScreenTouch and event.pressed
	if tapped or event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func show_game_over() -> void:
	_root.modulate.a = 0.0
	show()

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(_root, "modulate:a", 1.0, 0.6)
	tween.tween_callback(func() -> void: _can_restart = true)
