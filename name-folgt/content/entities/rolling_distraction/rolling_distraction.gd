class_name RollingDistraction
extends Distraction

@export var roll_speed := 6.0
@export var tumble_speed := 8.0
@export var warning_time := 1.5
@export var lifetime := 8.0

var _rolling := false

@onready var _warning: MeshInstance3D = $Warning


func _ready() -> void:
	super()

	var pulse := _warning.create_tween().set_loops()
	pulse.tween_property(_warning, "transparency", 0.3, 0.25)
	pulse.tween_property(_warning, "transparency", 0.8, 0.25)

	var timeline := create_tween()
	timeline.tween_interval(warning_time)
	timeline.tween_callback(_start_rolling)
	timeline.tween_interval(lifetime)
	timeline.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _rolling:
		return

	global_position += global_basis.z * roll_speed * delta
	mesh.rotate_x(tumble_speed * delta)


func _start_rolling() -> void:
	_warning.queue_free()
	_rolling = true
