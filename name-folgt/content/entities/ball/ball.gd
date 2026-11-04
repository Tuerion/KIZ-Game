extends RigidBody3D

@export var holder: Node3D
@export var hold_distance := 1.2
@export var radius := 0.5
@export var stiffness := 12.0 

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if holder == null:
		return

	var fwd := -holder.global_basis.z
	fwd.y = 0
	var target := holder.global_position + fwd.normalized() * hold_distance

	var to_target := target - global_position
	var vel := state.linear_velocity
	vel.x = to_target.x * stiffness
	vel.z = to_target.z * stiffness
	state.linear_velocity = vel


	var flat := Vector3(vel.x, 0, vel.z)
	state.angular_velocity = Vector3.UP.cross(flat) / radius
