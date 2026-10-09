extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var mission = load("res://Mission.tscn").instantiate()
	root.add_child(mission)
	for actor in mission.squad + mission.enemies:
		actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "graphical mouse capture enables actual player simulation")
	var start: Vector3 = mission.player.global_position
	Input.action_press("forward")
	Input.action_press("sprint")
	for i in range(30):
		await physics_frame
	Input.action_release("forward")
	Input.action_release("sprint")
	check(mission.player.global_position.z < start.z - 2, "W + Shift moves FPS body across solid ground")
	check(mission.player.stamina < 100, "sprint consumes stamina")
	Input.action_press("crouch")
	for i in range(3):
		await physics_frame
	check(mission.player.body_collision.shape.height < 1.2, "crouch lowers collision capsule")
	Input.action_release("crouch")
	Input.action_press("aim")
	for i in range(6):
		await physics_frame
	check(mission.player.aiming and mission.player.camera.fov < 75, "RMB narrows field of view")
	Input.action_press("fire")
	await physics_frame
	await physics_frame
	Input.action_release("fire")
	Input.action_release("aim")
	check(mission.player.ammo == 4 and mission.ballistics.shots_fired == 1, "trigger fires projectile and consumes cartridge")
	var reload_event := InputEventAction.new()
	reload_event.action = "reload"
	reload_event.pressed = true
	mission.player._unhandled_input(reload_event)
	check(mission.player.reload_time > 0, "R starts timed reload")
	mission.player.reload_time = 0.01
	await physics_frame
	await physics_frame
	check(mission.player.ammo == 5 and mission.player.reserve == 34, "reload draws cartridge from reserve")
	mission.player.position = mission.charge_points[0] + Vector3(0, 0.1, 0)
	mission.interaction = 2.99
	mission.current_action = "charge0"
	Input.action_press("interact")
	mission._process(0.02)
	Input.action_release("interact")
	check(mission.charges[0], "E interaction completes timed charge placement")
	mission.toggle_squad()
	check(not mission.following, "squad order toggles hold")
	var grenade_event := InputEventAction.new()
	grenade_event.action = "grenade"
	grenade_event.pressed = true
	mission.player._unhandled_input(grenade_event)
	check(mission.destruction.grenades_left == 1, "G input consumes one grenade")
	var thrown: Array = mission.destruction.find_children("*", "RigidBody3D", true, false)
	check(thrown.size() == 1 and thrown[0].collision_layer == 8 and thrown[0].linear_velocity.length() > 0, "G input launches a physical grenade")
	mission.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
