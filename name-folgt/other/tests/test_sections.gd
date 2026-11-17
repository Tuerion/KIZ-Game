extends SceneTree

const SLOPE := 0.2022

var cases := [
	{
		"path": "res://content/sections/start/start.tscn",
		"yaw": 0.0,
		"ground": [Vector2(0, 6), Vector2(3, 10), Vector2(0, -4)],
		"empty": [],
	},
	{
		"path": "res://content/sections/straight_slope/straight_slope.tscn",
		"yaw": 0.0,
		"ground": [Vector2(0, -20), Vector2(4, -35), Vector2(-4, -5)],
		"empty": [Vector2(6, -20)],
	},
	{
		"path": "res://content/sections/curve_left/curve_left.tscn",
		"yaw": 30.0,
		"ground": [Vector2(-2.9, -22.2), Vector2(-8, -38)],
		"empty": [Vector2(4, -30)],
	},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for case in cases:
		var scene: PackedScene = load(case.path)
		if scene == null:
			return _fail("%s missing" % case.path)
		var section: Section = scene.instantiate()
		root.add_child(section)
		for i in 5:
			await physics_frame

		var exit := section.exit
		if exit == null:
			return _fail("%s has no Exit" % case.path)
		if absf(rad_to_deg(exit.rotation.y) - case.yaw) > 2.0:
			return _fail("%s exit yaw %.1f, expected %.1f" % [case.path, rad_to_deg(exit.rotation.y), case.yaw])

		var back := exit.global_basis.z
		var height_near := _ground_height(exit.global_position + back * 0.5)
		if height_near == INF or absf(height_near - exit.global_position.y) > 1.0:
			return _fail("%s no ground right before the exit" % case.path)
		var height_far := _ground_height(exit.global_position + back * 3.0)
		var slope := (_ground_height(exit.global_position + back * 1.0) - height_far) / 2.0
		if absf(slope - SLOPE) > 0.03:
			return _fail("%s slope at exit %.3f, expected %.3f" % [case.path, slope, SLOPE])

		for point in case.ground:
			if _ground_height(Vector3(point.x, 0, point.y)) == INF:
				return _fail("%s no ground at %s" % [case.path, point])
		for point in case.empty:
			if _ground_height(Vector3(point.x, 0, point.y)) != INF:
				return _fail("%s ground where there should be a gap at %s" % [case.path, point])

		print("ok %s" % case.path.get_file())
		section.free()
	print("PASS")
	quit()


func _ground_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 40, point.z), Vector3(point.x, -10, point.z), 1)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return hit.position.y


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
