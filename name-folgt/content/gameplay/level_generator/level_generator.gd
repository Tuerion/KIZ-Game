class_name LevelGenerator
extends Node3D

@export var start_section: PackedScene
@export var sections: Array[PackedScene] = []
@export var player: Player
@export var ball: Ball
@export var build_distance := 60.0
@export var remove_depth := 15.0

@export_group("Difficulty")
@export var distraction_chance_start := 0.25
@export var distraction_chance_per_100m := 0.10
@export var distraction_chance_max := 0.70
@export var focus_chance := 0.30

var placed: Array[Section] = []
var start_height := 0.0

var _weights: PackedFloat32Array
var _min_heights: PackedFloat32Array
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	start_height = global_position.y
	for scene in sections:
		var section: Section = scene.instantiate()
		_weights.append(section.weight)
		_min_heights.append(section.min_height)
		section.free()

	_place(start_section.instantiate())
	_build_ahead()


func _physics_process(_delta: float) -> void:
	_build_ahead()
	_remove_behind()


func climbed_height() -> float:
	return player.global_position.y - start_height


func distraction_chance(height: float) -> float:
	return minf(distraction_chance_start + distraction_chance_per_100m * height / 100.0, distraction_chance_max)


func _build_ahead() -> void:
	while player.global_position.distance_to(placed.back().exit.global_position) < build_distance:
		_place(_pick_section())


func _remove_behind() -> void:
	while placed.size() > 1 and placed[0].exit.global_position.y < player.global_position.y - remove_depth:
		placed.pop_front().queue_free()


func _pick_section() -> Section:
	var weights := _weights.duplicate()
	for i in sections.size():
		if _next_height() < _min_heights[i]:
			weights[i] = 0.0
	return sections[_rng.rand_weighted(weights)].instantiate()


func _place(section: Section) -> void:
	add_child(section)
	if not placed.is_empty():
		section.global_transform = placed.back().exit.global_transform
	section.populate(ball, distraction_chance(_next_height()), focus_chance)
	placed.append(section)


func _next_height() -> float:
	if placed.is_empty():
		return 0.0
	return placed.back().exit.global_position.y - start_height
