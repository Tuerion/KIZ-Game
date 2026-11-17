class_name Ball
extends RigidBody3D

class Piece:
	var shape: CollisionShape3D
	var mesh: MeshInstance3D
	var weight: float

@export var max_up_speed := 3.0
@export var focus_time := 6.0
@export var wobble := 0.3

var focused := true

var radius: float:
	get:
		return _shape.radius

var distraction_count: int:
	get:
		return _pieces.size()

var _pieces: Array[Piece] = []
var _focus_timer := 0.0

@onready var _shape: SphereShape3D = $CollisionShape3D.shape
@onready var _mesh: SphereMesh = $MeshInstance3D.mesh


func _physics_process(delta: float) -> void:
	if _pieces.is_empty() or not focused:
		return

	_focus_timer += delta
	if _focus_timer >= focus_time:
		remove_distraction()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity.y = minf(state.linear_velocity.y, max_up_speed)


func add_distraction(distraction: Distraction) -> void:
	mass += distraction.weight
	_set_radius(radius + distraction.growth)
	global_position.y += distraction.growth
	distraction.stick_to(self)

	var piece := Piece.new()
	piece.shape = distraction.shape
	piece.mesh = distraction.mesh
	piece.weight = distraction.weight
	_pieces.append(piece)

	_focus_timer = 0.0
	_update_center_of_mass()


func remove_distraction() -> void:
	if _pieces.is_empty():
		return

	var piece: Piece = _pieces.pop_back()
	mass -= piece.weight
	piece.shape.queue_free()
	_pop_off(piece.mesh)

	_focus_timer = 0.0
	_update_center_of_mass()


func _set_radius(value: float) -> void:
	_shape.radius = value
	_mesh.radius = value
	_mesh.height = value * 2


func _update_center_of_mass() -> void:
	var weighted_sum := Vector3.ZERO
	for piece in _pieces:
		weighted_sum += piece.shape.position * piece.weight
	center_of_mass = weighted_sum / mass * wobble


func _pop_off(piece_mesh: MeshInstance3D) -> void:
	piece_mesh.reparent(get_parent())
	var outward := (piece_mesh.global_position - global_position).normalized() + Vector3.UP
	var tween := piece_mesh.create_tween().set_parallel()
	tween.tween_property(piece_mesh, "global_position", piece_mesh.global_position + outward * 0.5, 0.4)
	tween.tween_property(piece_mesh, "scale", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(piece_mesh.queue_free)
