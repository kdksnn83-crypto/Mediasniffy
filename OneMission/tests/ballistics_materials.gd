extends SceneTree
const Ballistics = preload("res://scripts/ballistics.gd")
const Impact = preload("res://scripts/impact_solver.gd")
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
func wait_steps(count: int) -> void:
	for i in range(count):
		await physics_frame
func run() -> void:
	var curve: Array = Ballistics.ammunition.drag_curve
	check(is_equal_approx(Ballistics.cd_from_mach(1, curve), 0.415), "Mach 1 curve knot preserved")
	check(is_equal_approx(Ballistics.cd_from_mach(1.05, curve), 0.4325), "Cd interpolated between transonic knots")
	check(is_equal_approx(Ballistics.cd_from_mach(-1, curve), 0.262) and is_equal_approx(Ballistics.cd_from_mach(5, curve), 0.210), "curve endpoint clamping")
	check(Ballistics.drag_acceleration(Vector3.ZERO, Vector3.ZERO) == Vector3.ZERO, "stationary round has no aerodynamic drag")
	var drag := Ballistics.drag_acceleration(Vector3(0, 0, -760), Vector3.ZERO)
	check(drag.dot(Vector3(0, 0, -760)) < 0, "drag opposes air-relative velocity")
	var area := PI * pow(0.00792 / 2, 2)
	var expected := 0.5 * 1.225 * 760 * 760 * area * Ballistics.cd_from_mach(760 / 343.0, curve) / 0.0128
	check(is_equal_approx(drag.length(), expected), "drag acceleration uses mass and area with SI units")
	check(absf(Ballistics.kinetic_energy(Vector3(0, 0, -760)) - 3696.64) < 0.01, "muzzle kinetic energy in joules")
	var mass := 0.0128
	var speed := Vector3(0, 0, -760)
	var normal := Vector3(0, 0, 1)
	var wood: Dictionary = Impact.materials.wood
	var steel: Dictionary = Impact.materials.steel
	var through := Impact.solve(speed, normal, mass, 0.2, wood)
	check(through.state == Impact.State.PENETRATED, "normal-incidence wooden wall can be penetrated")
	check(absf(0.5 * mass * through.velocity.length_squared() + through.energy_loss_j - 3696.64) < 0.02, "penetration conserves energy minus resistance work")
	check(Impact.solve(speed, normal, mass, 0.005, steel).state == Impact.State.STOPPED, "calibrated 5 mm steel stops reference round")
	var skim := Vector3(740, 0, -100)
	var bounce := Impact.solve(skim, normal, mass, 0.005, steel)
	check(bounce.state == Impact.State.RICOCHETED and bounce.velocity.z > 0, "grazing steel impact reflects away from surface")
	check(absf(bounce.velocity.length() / skim.length() - 0.4) < 0.0001, "ricochet preserves 40 percent speed, 16 percent energy")
	check(Impact.solve(Vector3.ZERO, normal, mass, 0.2, wood).state == Impact.State.STOPPED, "zero-speed impact is safe")
	check(Impact.solve(speed, normal, 0, 0.2, wood).state == Impact.State.STOPPED, "invalid mass fails closed")
	check(Impact.solve(speed, Vector3.ZERO, mass, 0.2, wood).state == Impact.State.STOPPED, "embedded hit with no normal fails closed")
	check(Impact.solve(speed, normal, mass, 0.2, Impact.materials.unknown).state == Impact.State.STOPPED, "unclassified material remains solid cover")
	check(absf(tan(Ballistics.dispersion_half_angle()) * 100 * 2 - 0.36) < 0.0001, "configured dispersion maps to diameter at range")
	var position := Vector3.ZERO
	var velocity := Vector3(0, 0, -100)
	var state: Dictionary
	for i in range(240):
		state = Ballistics.advance(position, velocity, Ballistics.STEP, Vector3.ZERO)
		position = state.position
		velocity = state.velocity
	var fine_position := Vector3.ZERO
	var fine_velocity := Vector3(0, 0, -100)
	for i in range(480):
		state = Ballistics.advance(fine_position, fine_velocity, Ballistics.STEP / 2, Vector3.ZERO)
		fine_position = state.position
		fine_velocity = state.velocity
	check(position.distance_to(fine_position) < 0.001, "RK2 integration converges under timestep refinement")
	var scene = load("res://Mission.tscn").instantiate()
	root.add_child(scene)
	for actor in scene.enemies + scene.squad:
		actor.set_physics_process(false)
	var panel = scene.box(scene, Vector3(55, 1.1, 30), Vector3(2, 2, 0.2), Color.GRAY, true, "wood")
	var guard := preload("res://scripts/soldier.gd").new()
	guard.position = Vector3(55, 0, 27)
	scene.add_child(guard)
	guard.set_physics_process(false)
	await wait_steps(2)
	var exit := Impact.box_exit(panel, 0, Vector3(55, 1.1, 30.1), Vector3(0, 0, -1))
	check(absf(float(exit.distance) - 0.2) < 0.0001, "box exit measures actual thickness")
	var oblique := Impact.box_exit(panel, 0, Vector3(55, 1.1, 30.1), Vector3(0.6, 0, -0.8))
	check(absf(float(oblique.distance) - 0.25) < 0.0001, "oblique path accounts for increased material thickness")
	panel.rotation.y = PI / 4
	var rotated := Impact.box_exit(panel, 0, panel.to_global(Vector3(0, 0, 0.1)), panel.global_basis * Vector3(0, 0, -1))
	check(absf(float(rotated.distance) - 0.2) < 0.0001, "exit solver respects transformed geometry")
	panel.rotation.y = 0
	panel.scale.z = 2
	var scaled := Impact.box_exit(panel, 0, Vector3(55, 1.1, 30.2), Vector3(0, 0, -1))
	check(absf(float(scaled.distance) - 0.4) < 0.0001, "scaled collision gives world-space path length")
	panel.scale.z = 1
	await wait_steps(2)
	scene.ballistics.fire(Vector3(55, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	await wait_steps(6)
	check(guard.health > 30 and guard.health < 60 and scene.ballistics.penetrations == 1, "wood penetration damages guard with reduced energy")
	guard.health = 100
	panel.set_meta("ballistic_material", "steel")
	scene.ballistics.fire(Vector3(55, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	await wait_steps(6)
	check(guard.health == 100, "thick steel collision blocks projectile in real world")
	panel.set_meta("ballistic_material", "wood")
	var second = scene.box(scene, Vector3(55, 1.1, 29.8), Vector3(2, 2, 0.005), Color.GRAY, true, "steel")
	await wait_steps(2)
	scene.ballistics.fire(Vector3(55, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	await wait_steps(6)
	check(guard.health == 100, "thin second obstacle is checked after first penetration in same tick")
	second.queue_free()
	var nested = scene.box(scene, Vector3(55, 1.1, 30), Vector3(2, 2, 0.005), Color.GRAY, true, "steel")
	await wait_steps(2)
	scene.ballistics.fire(Vector3(55, 1.1, 33), Vector3(0, 0, -1), scene.player, 95)
	await wait_steps(6)
	check(guard.health == 100, "embedded obstacle cannot be skipped inside penetrable material")
	nested.queue_free()
	panel.queue_free()
	guard.queue_free()
	var bounce_panel = scene.box(scene, Vector3(60, 1, 30), Vector3(10, 2, 0.005), Color.GRAY, true, "steel")
	await wait_steps(2)
	scene.ballistics.fire(Vector3(58, 1.1, 30.3), skim.normalized(), scene.player, 95)
	await wait_steps(2)
	check(scene.ballistics.ricochets == 1 and scene.ballistics.rounds.size() == 1 and scene.ballistics.rounds[0].v.z > 0, "real physics ricochet survives without re-hitting same surface")
	bounce_panel.queue_free()
	await wait_steps(2)
	Impact.materials["test_medium"] = {"resistance_j_per_m": 50.0, "ricochet_angle_deg": 90.0, "ricochet_speed_ratio": 0.0, "penetrable": true}
	var medium = scene.box(scene, Vector3(70, 1.1, 30), Vector3(2, 2, 30), Color.GRAY, true, "test_medium")
	var distant := preload("res://scripts/soldier.gd").new()
	distant.position = Vector3(70, 0, 12)
	scene.add_child(distant)
	distant.set_physics_process(false)
	# Remove the prior ricochet so this case has exactly one observed round.
	for bullet in scene.ballistics.rounds:
		bullet.visual.queue_free()
	scene.ballistics.rounds.clear()
	await wait_steps(2)
	scene.ballistics.fire(Vector3(70, 1.1, 48), Vector3(0, 0, -1), scene.player, 95)
	await wait_steps(2)
	check(distant.health == 100 and scene.ballistics.rounds.size() == 1 and not scene.ballistics.rounds[0].transit.is_empty(), "thick medium consumes multiple ticks instead of teleporting to exit")
	await wait_steps(6)
	check(distant.health < 100 and distant.health > 30, "projectile eventually exits thick medium with reduced energy")
	medium.queue_free()
	distant.queue_free()
	Impact.materials.erase("test_medium")
	scene.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
