extends SceneTree
const Destruction = preload("res://scripts/destruction.gd")
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
	var scene = load("res://Mission.tscn").instantiate()
	root.add_child(scene)
	for actor in scene.enemies + scene.squad + [scene.player]:
		actor.set_physics_process(false)
	scene.set_process(false)
	scene.player.position = Vector3(60, 0.1, 60)
	for soldier in scene.squad:
		soldier.position = Vector3(65, 0.1, 60)
	await wait_steps(2)
	var hut = scene.destruction.buildings[0]
	check(hut.tiles.size() == 60 and hut.supports == 20, "guard hut has 60 independently colliding tiles and 20 supports")
	var tile = hut.tiles[49]
	var origin: Vector3 = tile.global_position + Vector3(0, 0, -3)
	var query := PhysicsRayQueryParameters3D.create(tile.global_position + Vector3(0, 0, -0.3), tile.global_position + Vector3(0, 0, 0.3))
	query.collision_mask = 3
	check(scene.get_world_3d().direct_space_state.intersect_ray(query).collider == tile, "intact wall tile blocks actual ray")
	scene.ballistics.fire(origin, Vector3(0, 0, 1), scene.player, 95)
	await wait_steps(6)
	check(tile.health > 0 and tile.health < 100 and not tile.destroyed, "first real projectile deposits energy without erasing wall")
	scene.ballistics.fire(origin, Vector3(0, 0, 1), scene.player, 95)
	await wait_steps(6)
	check(tile.destroyed and not tile.visible and tile.collision_layer == 0, "second projectile creates visible and physical opening")
	check(scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "destroyed tile leaves no invisible bullet collision")
	check(scene.destruction.fragments.size() > 0, "destroyed tile spawns physical wood fragments")
	check(hut.lost_supports == 0 and not hut.collapsing, "non-support tile damage cannot collapse roof")
	var supports: Array = []
	for candidate in hut.tiles:
		if candidate.supports_roof:
			supports.append(candidate)
	for i in range(8):
		supports[i].apply_blast_damage(1000)
	check(hut.tiles[0].destroyed and hut.tiles[1].destroyed and hut.tiles[2].destroyed, "lost foundation removes unsupported panels above it")
	check(not hut.collapsing, "roof remains standing below support loss threshold")
	supports[8].apply_blast_damage(1000)
	check(hut.collapsing and hut.roof.collision_layer == 0, "45 percent support loss triggers collapse and clears overhead collision")
	var losses: int = hut.lost_supports
	supports[8].apply_blast_damage(1000)
	check(hut.lost_supports == losses, "repeated damage cannot count support twice")
	for i in range(80):
		await process_frame
	# Headless frames may be much faster than elapsed time; wait on physics time.
	await create_timer(1.3).timeout
	check(hut.collapsed and not hut.roof.visible, "prepared roof animation completes into resting wreckage")
	check(scene.destruction.fragments.size() <= int(scene.destruction.settings.debris_budget), "debris count stays within shared budget")
	var fragment: RigidBody3D = scene.destruction.fragments[0].node
	check(fragment.mass > 0 and fragment.collision_layer == 4 and fragment.collision_mask == 1, "fragments have mass and world collision without blocking characters")
	check(Destruction.falloff(0, 10) == 1 and Destruction.falloff(10, 10) == 0 and Destruction.falloff(15, 10) == 0, "blast falloff stops at configured radius")
	check(is_equal_approx(Destruction.falloff(5, 10), 0.25), "blast damage declines with range")
	check(Destruction.falloff(5, 0) == 0, "zero-radius blast is safe")
	var target = scene.enemies[0]
	target.position = Vector3(80, 0, 30)
	var shield = scene.box(scene, Vector3(80, 1.0, 32.5), Vector3(3, 3, 0.2), Color.GRAY, true, "steel")
	await wait_steps(2)
	scene.destruction.explode(Vector3(80, 1, 35), 10, 100, false)
	var shielded: float = 100 - target.health
	check(shielded > 0 and shielded < 5, "solid cover attenuates blast damage to character")
	shield.queue_free()
	await wait_steps(2)
	target.health = 100
	scene.destruction.explode(Vector3(80, 1, 35), 10, 100, false)
	check(target.health < 80 and target.health > 70, "unshielded character receives stronger blast at same range")
	var blast_hut = scene.destruction.build_hut(Vector3(60, 0, 20))
	target.health = 100
	target.position = Vector3(58.5, 0, 19)
	await wait_steps(2)
	scene.destruction.explode(Vector3(58.5, 1, 15), 10, 1000, false)
	check(blast_hut.tiles[51].destroyed and target.health > 0 and target.health < 100, "cover is snapshotted before same explosion opens wall")
	var old_wetness: float = scene.weather.wetness
	var entry: Dictionary = scene.weather.registered[0]
	scene.weather.set_wetness(0)
	var dry: float = entry.material.roughness
	scene.weather.set_wetness(1)
	check(entry.material.roughness < dry and scene.weather.wetness == 1, "global wetness reduces exterior roughness")
	scene.weather.set_wetness(2)
	check(scene.weather.wetness == 1, "wetness clamps to valid range")
	scene.weather.set_wetness(old_wetness)
	check(scene.weather.puddles.size() == 18 and scene.weather.water != null, "bounded puddle set and animated river are present")
	check(scene.weather.sheltered(scene.escape_point + Vector3.UP * 1.5), "partisan roof blocks rain beneath it")
	check(not scene.weather.sheltered(hut.global_position + Vector3.UP * 1.5), "collapsed guard roof no longer blocks rain")
	target.position = Vector3(80, 0, 30)
	target.health = 100
	var stock: int = scene.destruction.grenades_left
	var grenade = scene.destruction.throw_grenade()
	check(grenade != null and scene.destruction.grenades_left == stock - 1 and grenade.fuse == 3, "throw consumes grenade and sets three-second fuse")
	grenade.position = Vector3(80, 1, 35)
	grenade.linear_velocity = Vector3.ZERO
	grenade.fuse = 0.01
	var blasts: int = scene.destruction.explosions
	grenade._physics_process(0.02)
	check(grenade.detonated and scene.destruction.explosions == blasts + 1 and target.health < 100, "grenade fuse triggers actual area damage once")
	grenade._physics_process(1)
	check(scene.destruction.explosions == blasts + 1, "detonated grenade cannot explode twice")
	scene.destruction.grenades_left = 0
	check(scene.destruction.throw_grenade() == null, "empty grenade supply blocks throwing")
	var debris_nodes: Array = []
	for item in scene.destruction.fragments:
		debris_nodes.append(item.node)
	scene.destruction._physics_process(5)
	check(scene.destruction.fragments.is_empty(), "debris expires from manager after lifetime")
	await process_frame
	check(not is_instance_valid(debris_nodes[0]), "expired debris body is freed from world")
	var safe_explosions: int = scene.destruction.explosions
	scene.destruction.explode(Vector3.ZERO, 0, 100)
	check(scene.destruction.explosions == safe_explosions, "invalid explosion produces no effects")
	scene.player.position = Vector3(82, 0, 35)
	for i in range(scene.squad.size()):
		scene.squad[i].position = Vector3(79 + i * 0.5, 0, 35)
	await wait_steps(2)
	scene.destruction.explode(Vector3(80, 1, 35), 10, 1000, false)
	check(scene.ended and scene.survivors() == 0 and scene.result.text.contains("Gefallene: 4"), "fatal blast reports squad losses after applying all actor damage")
	scene.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
