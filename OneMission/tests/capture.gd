extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://"
	DirAccess.make_dir_recursive_absolute(output)
	var mission = load("res://Mission.tscn").instantiate()
	root.add_child(mission)
	for actor in mission.enemies + mission.squad:
		actor.set_physics_process(false)
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/Nasser-Stahl-Spielansicht.png")
	Input.action_press("map")
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/Nasser-Stahl-Feldkarte.png")
	Input.action_release("map")
	mission.queue_free()
	await process_frame
	quit()
