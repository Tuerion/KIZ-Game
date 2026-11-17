class_name Section
extends Node3D

@export var min_height := 0.0
@export var weight := 1.0
@export var distraction_scene: PackedScene = preload("res://content/entities/distraction/distraction.tscn")
@export var focus_scene: PackedScene = preload("res://content/entities/focus_ball/focus_ball.tscn")

@onready var exit: Marker3D = $Exit


func populate(ball: Ball, distraction_chance: float, focus_chance: float) -> void:
	_fill($DistractionSpots, distraction_scene, distraction_chance)
	_fill($FocusSpots, focus_scene, focus_chance)
	for child in find_children("*", "", true, false):
		if child is DistractionSpawner:
			child.ball = ball


func _fill(spots: Node3D, scene: PackedScene, chance: float) -> void:
	for spot in spots.get_children():
		if randf() < chance:
			spot.add_child(scene.instantiate())
