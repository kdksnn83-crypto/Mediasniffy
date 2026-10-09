extends SceneTree
const Ballistics = preload("res://scripts/ballistics.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var position := Vector3.ZERO
	var velocity := Vector3(0, 0, -760)
	var flight := 0.0
	while position.z > -100:
		var step := Ballistics.advance(position, velocity, Ballistics.STEP, Vector3.ZERO)
		position = step.position
		velocity = step.velocity
		flight += Ballistics.STEP
	check(flight > 0.13 and flight < 0.15, "100 m flight time is finite and physically plausible")
	check(position.y < -0.08 and position.y > -0.12, "100 m gravity drop")
	check(velocity.length() < 760 and velocity.length() > 700, "air drag reduces speed")
	var drift := Ballistics.advance(Vector3.ZERO, Vector3(0, 0, -760), 0.1, Vector3(10, 0, 0))
	check(drift.position.x > 0, "crosswind changes bullet path")
	check(Ballistics.zero_angle(300) > Ballistics.zero_angle(100), "longer sight zero raises bore elevation")
	var scene = load("res://Mission.tscn").instantiate()
	root.add_child(scene)
	for actor in scene.enemies + scene.squad:
		actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(scene.squad.size() == 3 and scene.enemies.size() == 4, "mission spawns four-person squad and four initial guards")
	check(scene.player.camera.current and scene.player.ammo == 5, "FPS camera and rifle initialized")
	check(not scene.all_across(), "detonation blocked while squad on south bank")
	scene.perform_action("detonate")
	check(not scene.bridge_destroyed, "missing charges cannot trigger bridge destruction")
	scene.perform_action("charge0")
	scene.perform_action("charge1")
	scene.perform_action("detonate")
	check(not scene.bridge_destroyed, "charges alone do not bypass squad safety")
	# A bullet must stop on existing crate geometry, not hit a guard behind it.
	var blocker = scene.box(scene, Vector3(50, 1, 30), Vector3(2, 2, 0.4), Color.GRAY, true)
	var target := preload("res://scripts/soldier.gd").new()
	target.position = Vector3(50, 0, 27)
	scene.add_child(target)
	target.set_physics_process(false)
	await physics_frame
	await physics_frame
	scene.ballistics.fire(Vector3(50, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	for i in range(6):
		await physics_frame
	check(target.health == 100 and scene.ballistics.rounds.is_empty(), "solid cover stops projectile before guard")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	scene.ballistics.fire(Vector3(50, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	for i in range(6):
		await physics_frame
	check(target.health < 10 and target.health > 0, "unblocked projectile damages guard with retained energy")
	target.queue_free()
	# Let followers cross using their real movement and collision code.
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
	scene.player.position = Vector3(0, 0.5, -16)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for soldier in scene.squad:
		soldier.set_physics_process(true)
		soldier.position = Vector3((soldier.slot - 1) * 1.1, 0.5, 12)
	for i in range(540):
		await physics_frame
	for soldier in scene.squad:
		print("CROSSING POSITION: ", soldier.global_position)
	check(scene.all_across(), "all three followers cross bridge through real physics")
	scene.player.position = scene.detonation_point + Vector3.UP * 0.1
	check(scene.nearby_action() == "detonate", "detonation point offers interaction")
	scene.train_clock = 40
	scene.update_train(0)
	scene.perform_action("train")
	scene.perform_action("detonate")
	await physics_frame
	check(scene.bridge_destroyed and not scene.bridge.visible, "detonation replaces intact bridge")
	check(scene.train_destroyed and not scene.train.visible, "sabotaged train destroyed during unloading")
	check(scene.enemies.size() == 6, "only two reinforcements added on existing road")
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0))
	query.collision_mask = 3
	check(scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "destroyed bridge no longer has traversable collision")
	scene.player.position = scene.escape_point
	for soldier in scene.squad:
		soldier.position = scene.escape_point + Vector3(soldier.slot, 0.1, 1)
	check(scene.nearby_action() == "escape", "partisan hut offers extraction")
	scene.perform_action("escape")
	check(scene.ended and scene.result.text.contains("MISSION ABGESCHLOSSEN"), "mission ends with successful debrief")
	scene.queue_free()
	await process_frame
	# Second independent branch: optional train missed, main objective still works.
	var second = load("res://Mission.tscn").instantiate()
	root.add_child(second)
	await physics_frame
	second.charges = [true, true]
	second.player.position = Vector3(8, 0.1, -18)
	for soldier in second.squad:
		soldier.position = Vector3(0, 0.1, -18)
	second.train_clock = 250
	second.update_train(0)
	second.perform_action("detonate")
	check(second.bridge_destroyed and not second.train_destroyed, "bridge objective succeeds even after train departs")
	second.player.take_damage(100)
	check(second.ended and second.result.text.contains("GESCHEITERT"), "player death fails mission")
	second.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
