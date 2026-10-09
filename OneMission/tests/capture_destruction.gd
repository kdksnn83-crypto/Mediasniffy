extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func photograph(output: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://"
	DirAccess.make_dir_recursive_absolute(output)
	var mission = load("res://Mission.tscn").instantiate()
	root.add_child(mission)
	for actor in mission.enemies + mission.squad + [mission.player]:
		actor.set_physics_process(false)
	mission.player.position = Vector3(17, 0.1, 11)
	mission.player.camera.look_at(Vector3(14, 1.4, 18))
	await photograph(output + "/Wachhuette-vorher.png")
	var hut = mission.destruction.buildings[0]
	for tile in hut.tiles:
		if tile.position.z < -2 or tile.supports_roof:
			tile.apply_blast_damage(1000)
	await create_timer(1.4).timeout
	await photograph(output + "/Wachhuette-zerstoert.png")
	mission.player.position = Vector3(-5, 0.2, 5)
	mission.player.camera.look_at(Vector3(-12, -1, 0))
	await photograph(output + "/Fluss-Wasser.png")
	mission.player.position = Vector3(1, 0.1, 27)
	var puddle: MeshInstance3D = mission.weather.puddles[0]
	mission.player.camera.look_at(puddle.global_position)
	await photograph(output + "/Pfuetzen-Regen.png")
	mission.queue_free()
	await process_frame
	quit()
