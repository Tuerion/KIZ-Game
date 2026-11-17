extends SceneTree

const SECTION_SCRIPT := "res://content/sections/section/section.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ball: Ball = load("res://content/entities/ball/ball.tscn").instantiate()
	root.add_child(ball)
	ball.freeze = true

	var full := _make_section(5, 3)
	full.populate(ball, 1.0, 0.0)
	await process_frame
	if _count(full, Distraction) != 5 or _count(full, FocusBall) != 0:
		return _fail("chance 1/0 gave %d distractions, %d focus" % [_count(full, Distraction), _count(full, FocusBall)])

	var focus_only := _make_section(5, 3)
	focus_only.populate(ball, 0.0, 1.0)
	await process_frame
	if _count(focus_only, Distraction) != 0 or _count(focus_only, FocusBall) != 3:
		return _fail("chance 0/1 gave %d distractions, %d focus" % [_count(focus_only, Distraction), _count(focus_only, FocusBall)])
	full.free()
	focus_only.free()

	var spawner: DistractionSpawner = load("res://content/gameplay/distraction_spawner/distraction_spawner.tscn").instantiate()
	spawner.curve = Curve3D.new()
	spawner.curve.add_point(Vector3.ZERO)
	spawner.curve.add_point(Vector3(0, 0, -20))
	spawner.spawn_distance = 25.0
	spawner.min_interval = 0.5
	spawner.max_interval = 0.5
	var lane_section := _make_section(0, 0)
	lane_section.add_child(spawner)
	lane_section.populate(ball, 0.0, 0.0)
	if spawner.ball != ball:
		return _fail("populate did not hand the ball to the spawner")

	ball.global_position = Vector3(0, 0.5, 5)
	await _wait(3.0)
	if spawner.get_child_count() != 0:
		return _fail("spawned while ball was below the lane")

	ball.global_position = Vector3(0, 0.5, -10)
	await _wait(1.0)
	if spawner.get_child_count() == 0:
		return _fail("nothing spawned while ball was on the lane")
	var spawned: Node3D = spawner.get_child(0)
	if not is_equal_approx(spawned.position.z, -20.0):
		return _fail("spawned at z=%.2f instead of the lane end -20" % spawned.position.z)

	print("PASS")
	quit()


func _make_section(distraction_spots: int, focus_spots: int) -> Section:
	var base := Node3D.new()
	base.set_script(load(SECTION_SCRIPT))
	var section: Section = base
	section.distraction_scene = load("res://content/entities/distraction/distraction.tscn")
	section.focus_scene = load("res://content/entities/focus_ball/focus_ball.tscn")
	for node_name in ["Exit", "DistractionSpots", "FocusSpots"]:
		var child := Marker3D.new() if node_name == "Exit" else Node3D.new()
		child.name = node_name
		section.add_child(child)
	for i in distraction_spots:
		var spot := Marker3D.new()
		spot.position = Vector3(i * 2, 0.5, -10)
		section.get_node("DistractionSpots").add_child(spot)
	for i in focus_spots:
		var spot := Marker3D.new()
		spot.position = Vector3(i * 2, 0.5, -20)
		section.get_node("FocusSpots").add_child(spot)
	root.add_child(section)
	return section


func _count(node: Node, type: Variant) -> int:
	var total := 0
	for child in node.find_children("*", "", true, false):
		if is_instance_of(child, type):
			total += 1
	return total


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
