extends Node3D
const Grenade = preload("res://scripts/grenade.gd")
const Hut = preload("res://scripts/destructible_hut.gd")
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/destruction_weather.json"))
var mission: Node3D
var buildings: Array = []
var fragments: Array[Dictionary] = []
var grenades_left := 2
var explosions := 0
var audio: AudioStreamPlayer

func _ready() -> void:
	mission = get_parent()
	grenades_left = int(settings.grenade_count)
	audio = AudioStreamPlayer.new()
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.stream = mission.make_noise(0.8, 0.35)
	add_child(audio)

func build_hut(position_in_world: Vector3) -> Node3D:
	var hut := Hut.new()
	hut.mission = mission
	mission.add_child(hut)
	hut.build(position_in_world)
	buildings.append(hut)
	return hut

func spawn_fragment(point: Vector3, size: Vector3, impulse: Vector3, kind: String = "wood") -> RigidBody3D:
	if fragments.size() >= int(settings.debris_budget):
		return null
	var body := RigidBody3D.new()
	body.mass = maxf(0.1, size.x * size.y * size.z * (7800 if kind == "steel" else 500))
	body.collision_layer = 4
	body.collision_mask = 1 # World only; characters use layer 2.
	body.linear_damp = 0.15
	body.angular_damp = 0.25
	body.can_sleep = true
	add_child(body)
	body.global_position = point
	mission.box(body, Vector3.ZERO, size, Color(0.21, 0.24, 0.25) if kind == "steel" else Color(0.28, 0.22, 0.16))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.linear_velocity = impulse
	body.angular_velocity = Vector3(2, 1, 3)
	fragments.append({"node": body, "life": float(settings.debris_lifetime_seconds)})
	return body

func break_tile(tile: StaticBody3D) -> void:
	for i in range(3):
		spawn_fragment(tile.global_position + Vector3((i - 1) * 0.2, 0.1, 0), Vector3(0.18, 0.28, 0.08), Vector3((i - 1) * 2, 2.5, 0.8))
	# Attach edge splinters to surviving neighboring panels. When a neighbor
	# disappears its splinters disappear too; no floating edges remain.
	for side in [-1, 1]:
		var edge_neighbor: Vector3 = tile.global_position + tile.global_basis.x * side
		for neighbor in tile.building.tiles:
			if neighbor.destroyed or neighbor.global_position.distance_to(edge_neighbor) > 0.02:
				continue
			var splinter: Node3D = mission.box(neighbor, Vector3(-side * 0.48, 0, 0), Vector3(0.08, 0.28, 0.12), Color(0.48, 0.36, 0.2))
			splinter.rotation.z = side * 0.28
			break

static func falloff(distance: float, radius: float) -> float:
	if radius <= 0:
		return 0.0
	return pow(clampf(1 - distance / radius, 0, 1), 2)

func cover_multiplier(origin: Vector3, target: CollisionObject3D, point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.collision_mask = 1 # Structural cover; bodies do not shield blast.
	query.hit_from_inside = true
	var contact := get_world_3d().direct_space_state.intersect_ray(query)
	if contact.is_empty() or contact.collider == target:
		return 1.0
	return float(settings.blast_cover_multiplier)

func explode(origin: Vector3, radius: float, peak_damage: float, visuals: bool = true) -> void:
	if radius <= 0 or peak_damage <= 0:
		return
	explosions += 1
	# Snapshot all cover/damage BEFORE applying changes. Opening a wall in this
	# explosion must not retroactively expose someone to the same blast.
	var pending: Array[Dictionary] = []
	var actors: Array = mission.squad.duplicate()
	actors.append_array(mission.enemies)
	# Apply player damage last so a fatal blast reports the final squad losses.
	actors.append(mission.player)
	for actor in actors:
		if not is_instance_valid(actor) or actor.health <= 0:
			continue
		var point: Vector3 = actor.global_position + Vector3.UP * 0.9
		var damage := peak_damage * falloff(origin.distance_to(point), radius) * cover_multiplier(origin, actor, point)
		if damage > 0:
			pending.append({"node": actor, "damage": damage, "actor": true})
	for building in buildings:
		for tile in building.tiles:
			if tile.destroyed:
				continue
			var damage := peak_damage * falloff(origin.distance_to(tile.global_position), radius) * cover_multiplier(origin, tile, tile.global_position)
			if damage > 0:
				pending.append({"node": tile, "damage": damage, "actor": false})
	for entry in pending:
		if entry.actor:
			entry.node.take_damage(entry.damage)
		else:
			entry.node.apply_blast_damage(entry.damage)
	for fragment in fragments:
		var body: RigidBody3D = fragment.node
		var offset := body.global_position - origin
		var force := falloff(offset.length(), radius)
		if force > 0:
			body.apply_central_impulse((offset.normalized() + Vector3.UP * 0.4) * force * body.mass * 4)
	if visuals:
		visual_explosion(origin)
		mission.alert(origin)

func visual_explosion(origin: Vector3) -> void:
	audio.play()
	var light := OmniLight3D.new()
	light.position = origin + Vector3.UP
	light.light_energy = 6
	light.light_color = Color(1, 0.48, 0.12)
	light.omni_range = 15
	mission.add_child(light)
	mission.effects.append({"node": light, "life": 0.25})
	for i in range(6):
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.55 + i * 0.12
		sphere.height = sphere.radius * 2
		sphere.radial_segments = 8
		sphere.rings = 4
		cloud.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.23, 0.24, 0.24, 0.65)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud.material_override = mat
		mission.add_child(cloud)
		cloud.position = origin + Vector3((i % 3 - 1) * 0.6, 0.5 + i * 0.35, (i % 2) * 0.5)
		var tween := cloud.create_tween().set_parallel(true)
		tween.tween_property(cloud, "scale", Vector3.ONE * 2.2, 2.5)
		tween.tween_property(cloud, "position:y", cloud.position.y + 2, 2.5)
		tween.tween_property(mat, "albedo_color:a", 0.0, 3)
		mission.effects.append({"node": cloud, "life": 3.2})

func throw_grenade() -> RigidBody3D:
	if grenades_left <= 0 or mission.ended:
		return null
	grenades_left -= 1
	var grenade := Grenade.new()
	grenade.mission = mission
	grenade.fuse = float(settings.grenade_fuse_seconds)
	grenade.mass = 0.4
	grenade.collision_layer = 8
	grenade.collision_mask = 1
	var camera: Camera3D = mission.player.camera
	var direction := -camera.global_basis.z
	var origin := camera.global_position
	var spawn := origin + direction * 0.6
	var query := PhysicsRayQueryParameters3D.create(origin, spawn)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = hit.position - direction * 0.14
	add_child(grenade)
	grenade.global_position = spawn
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.26, 0.16)
	mesh.material_override = mat
	grenade.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	collision.shape = shape
	grenade.add_child(collision)
	grenade.linear_velocity = direction * 12 + Vector3.UP * 3 + mission.player.velocity * 0.4
	grenade.angular_velocity = Vector3(4, 2, 1)
	return grenade

func _physics_process(delta: float) -> void:
	for i in range(fragments.size() - 1, -1, -1):
		fragments[i].life -= delta
		if fragments[i].life <= 0:
			fragments[i].node.queue_free()
			fragments.remove_at(i)
