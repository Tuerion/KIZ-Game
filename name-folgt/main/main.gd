class_name Main
extends Node

@export var level_scene: PackedScene

var level: Node


func _ready() -> void:
	start_game()


func start_game() -> void:
	if level:
		level.free()
	level = level_scene.instantiate()
	add_child(level)
