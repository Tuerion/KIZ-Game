class_name Ball
extends RigidBody3D

@onready var _shape: SphereShape3D = $CollisionShape3D.shape
@onready var _mesh: SphereMesh = $MeshInstance3D.mesh

var radius: float:
	get:
		return _shape.radius


func add_distraction(distraction: Distraction) -> void:
	mass += distraction.weight
	_shape.radius += distraction.growth
	_mesh.radius = _shape.radius
	_mesh.height = _shape.radius * 2
	distraction.stick_to(self)
