class_name RollingDistraction
extends Distraction

@export var roll_speed := 6.0
@export var tumble_speed := 8.0
@export var hover := 0.2
@export var warning_time := 1.5
@export var warning_length := 30.0
@export var warning_spacing := 2.0
@export var warning_mesh: Mesh

var lane: Path3D
var progress := 0.0
var side := 0.0

@onready var _warning: Node3D = $Warning


func _ready() -> void:
	super()
	set_physics_process(false)
	transform = _lane_transform(progress)
	_build_warning()

	var pulse := _warning.create_tween().set_loops()
	pulse.tween_method(_set_warning_transparency, 0.3, 0.8, 0.25)
	pulse.tween_method(_set_warning_transparency, 0.8, 0.3, 0.25)
	create_tween().tween_callback(_start_rolling).set_delay(warning_time)


func _physics_process(delta: float) -> void:
	progress -= roll_speed * delta
	if progress <= 0.0:
		queue_free()
		return

	transform = _lane_transform(progress)
	mesh.rotate_x(tumble_speed * delta)


func _lane_transform(at_progress: float) -> Transform3D:
	var lane_point := lane.curve.sample_baked_with_rotation(at_progress)
	return lane_point.translated_local(Vector3(side, hover, 0))


func _build_warning() -> void:
	var mark_progress := progress
	while mark_progress > maxf(0.0, progress - warning_length):
		var mark := MeshInstance3D.new()
		mark.mesh = warning_mesh
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_warning.add_child(mark)
		mark.global_transform = lane.global_transform * _lane_transform(mark_progress).translated_local(Vector3.DOWN * hover)
		mark_progress -= warning_spacing


func _set_warning_transparency(value: float) -> void:
	for mark: MeshInstance3D in _warning.get_children():
		mark.transparency = value


func _start_rolling() -> void:
	_warning.queue_free()
	set_physics_process(true)
