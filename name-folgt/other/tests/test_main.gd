extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://main/main.tscn")
	if main_scene == null:
		_fail("main.tscn missing")
		return
	var main: Main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if main.level == null or main.level.get_parent() != main:
		_fail("level not loaded as child of Main")
		return

	main.start_game()
	await process_frame
	await process_frame
	if main.get_child_count() != 1:
		_fail("expected exactly one level after restart, got %d" % main.get_child_count())
		return

	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if main_path.begins_with("uid://"):
		main_path = ResourceUID.get_id_path(ResourceUID.text_to_id(main_path))
	if main_path != "res://main/main.tscn":
		_fail("main scene is %s" % main_path)
		return
	print("PASS")
	quit()


func _fail(reason: String) -> void:
	print("FAIL: " + reason)
	quit(1)
