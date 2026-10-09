extends Node3D
const Impact = preload("res://scripts/impact_solver.gd")
const GRAVITY := Vector3(0, -9.81, 0)
const SPEED := 760.0 # Test reference; actual muzzle speed comes from ammunition.
const STEP := 1.0 / 240.0
const EPSILON := 0.0001
static var ammunition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/rifle_ammunition.json"))
var rounds: Array[Dictionary] = []
var wind := Vector3(1.2, 0, 0)
var zero_range := 100
var bore_angle := 0.0
var shots_fired := 0
var hits := 0
var penetrations := 0
var ricochets := 0

static func cd_from_mach(mach: float, table: Array) -> float:
	if table.is_empty():
		return 0.0
	if mach <= float(table[0][0]):
		return float(table[0][1])
	for i in range(table.size() - 1):
		var lower: float = table[i][0]
		var upper: float = table[i + 1][0]
		if mach <= upper:
			return lerpf(float(table[i][1]), float(table[i + 1][1]), (mach - lower) / (upper - lower))
	return float(table[-1][1])

static func drag_acceleration(velocity: Vector3, wind_velocity: Vector3) -> Vector3:
	var relative := velocity - wind_velocity
	var speed := relative.length()
	if speed < 0.001:
		return Vector3.ZERO
	var cd := cd_from_mach(speed / float(ammunition.speed_of_sound_mps), ammunition.drag_curve)
	var area := PI * pow(float(ammunition.diameter_m) * 0.5, 2)
	var factor := 0.5 * float(ammunition.air_density_kg_m3) * area * cd * float(ammunition.form_factor) / float(ammunition.mass_kg)
	return -relative * speed * factor

static func acceleration(velocity: Vector3, wind_velocity: Vector3) -> Vector3:
	return GRAVITY + drag_acceleration(velocity, wind_velocity)

static func advance(position: Vector3, velocity: Vector3, dt: float, wind_velocity: Vector3) -> Dictionary:
	# Explicit midpoint (RK2), including the Mach-dependent drag curve.
	var middle_velocity := velocity + acceleration(velocity, wind_velocity) * dt * 0.5
	return {"position": position + middle_velocity * dt, "velocity": velocity + acceleration(middle_velocity, wind_velocity) * dt}

static func dispersion_half_angle() -> float:
	return atan2(float(ammunition.dispersion_diameter_m) * 0.5, float(ammunition.dispersion_range_m))

static func kinetic_energy(velocity: Vector3) -> float:
	return 0.5 * float(ammunition.mass_kg) * velocity.length_squared()

func _ready() -> void:
	assert(float(ammunition.mass_kg) > 0 and float(ammunition.diameter_m) > 0)
	assert(float(ammunition.muzzle_velocity_mps) > 0 and float(ammunition.speed_of_sound_mps) > 0)
	assert(float(ammunition.dispersion_range_m) > 0)
	bore_angle = zero_angle(zero_range)

static func zero_angle(distance: float) -> float:
	var low := 0.0
	var high := 0.04
	for iteration in range(12):
		var angle := (low + high) * 0.5
		var position := Vector3.ZERO
		var velocity := Vector3(0, sin(angle), -cos(angle)) * float(ammunition.muzzle_velocity_mps)
		var time := 0.0
		while position.z > -distance and time < 10:
			var previous := position
			var state := advance(position, velocity, STEP, Vector3.ZERO)
			position = state.position
			velocity = state.velocity
			time += STEP
			if position.z <= -distance:
				position = previous.lerp(position, (-distance - previous.z) / (position.z - previous.z))
		if position.y > 0:
			high = angle
		else:
			low = angle
	return (low + high) * 0.5

func adjust_zero(amount: int) -> void:
	zero_range = clampi(zero_range + amount, 100, 400)
	bore_angle = zero_angle(zero_range)

func fire(origin: Vector3, direction: Vector3, owner_body: CollisionObject3D, damage: float, hostile: bool = false) -> void:
	if rounds.size() >= 96 or direction.length_squared() < 0.000001:
		return
	var tracer := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	tracer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.73, 0.32)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = material
	add_child(tracer)
	tracer.global_position = origin
	var aim := direction.normalized()
	var right := aim.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	var bore := aim.rotated(right, bore_angle)
	rounds.append({"p": origin, "v": bore * float(ammunition.muzzle_velocity_mps), "age": 0.0, "exclude": [owner_body.get_rid()], "damage": damage, "hostile": hostile, "visual": tracer, "impacts": 0, "transit": {}})
	if not hostile:
		shots_fired += 1

func ray(start: Vector3, end: Vector3, excluded: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = excluded
	query.collision_mask = 3
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func damage_actor(contact: Dictionary, bullet: Dictionary) -> void:
	if contact.collider.has_method("take_damage"):
		var muzzle := float(ammunition.muzzle_velocity_mps)
		var energy_ratio := clampf(bullet.v.length_squared() / (muzzle * muzzle), 0, 1)
		contact.collider.take_damage(bullet.damage * energy_ratio)
		if not bullet.hostile:
			hits += 1

func _physics_process(delta: float) -> void:
	for index in range(rounds.size() - 1, -1, -1):
		var bullet: Dictionary = rounds[index]
		var remaining := delta
		var dead := false
		while remaining > 0.000001:
			var dt := minf(STEP, remaining)
			if not bullet.transit.is_empty():
				# Material travel consumes real simulation time, not a teleport.
				var transit: Dictionary = bullet.transit
				dt = minf(dt, transit.time)
				var speed: float = bullet.v.length()
				var next_speed := maxf(transit.exit_speed, speed - transit.deceleration * dt)
				var next_position: Vector3 = bullet.p + transit.direction * ((speed + next_speed) * 0.5 * dt)
				var excluded: Array = bullet.exclude.duplicate()
				excluded.append(transit.rid)
				var nested := ray(bullet.p, next_position, excluded)
				bullet.v = transit.direction * next_speed
				if not nested.is_empty():
					# Overlapping/embedded obstacles conservatively stop the round.
					damage_actor(nested, bullet)
					get_parent().impact(nested.position)
					dead = true
					break
				bullet.p = next_position
				bullet.age += dt
				remaining -= dt
				transit.time -= dt
				if transit.time <= 0.000001:
					bullet.p = transit.exit_position + transit.direction * EPSILON
					bullet.v = transit.direction * transit.exit_speed
					bullet.transit = {}
				continue
			var state := advance(bullet.p, bullet.v, dt, wind)
			var contact := ray(bullet.p, state.position, bullet.exclude)
			if contact.is_empty():
				bullet.p = state.position
				bullet.v = state.velocity
				bullet.age += dt
				remaining -= dt
				continue
			var fraction := clampf(bullet.p.distance_to(contact.position) / maxf(EPSILON, bullet.p.distance_to(state.position)), 0, 1)
			var consumed := dt * fraction
			bullet.v = advance(bullet.p, bullet.v, consumed, wind).velocity
			bullet.p = contact.position
			bullet.age += consumed
			remaining -= consumed
			get_parent().impact(contact.position)
			bullet.impacts += 1
			if contact.collider.has_method("take_damage"):
				damage_actor(contact, bullet)
				dead = true
				break
			if bullet.impacts > 6 or contact.normal.length_squared() < 0.000001:
				dead = true
				break
			var direction: Vector3 = bullet.v.normalized()
			var exit_info := Impact.box_exit(contact.collider, contact.shape, contact.position, direction)
			var thickness := float(exit_info.get("distance", 0))
			var material_name: String = contact.collider.get_meta("ballistic_material", "unknown")
			var surface: Dictionary = Impact.materials.get(material_name, Impact.materials.unknown)
			var response := Impact.solve(bullet.v, contact.normal, float(ammunition.mass_kg), thickness, surface)
			if contact.collider.has_method("apply_projectile_energy"):
				contact.collider.apply_projectile_energy(response.energy_loss_j)
			if response.state == Impact.State.RICOCHETED:
				ricochets += 1
				bullet.v = response.velocity
				bullet.p = contact.position + contact.normal * EPSILON
			elif response.state == Impact.State.PENETRATED and not exit_info.is_empty():
				penetrations += 1
				var exit_speed: float = response.velocity.length()
				bullet.transit = {"time": 2 * thickness / (bullet.v.length() + exit_speed), "deceleration": float(surface.resistance_j_per_m) / float(ammunition.mass_kg), "direction": direction, "exit_speed": exit_speed, "exit_position": exit_info.position, "rid": contact.collider.get_rid()}
				bullet.p = contact.position + direction * EPSILON
			else:
				dead = true
				break
		if dead or bullet.age > 4.0 or bullet.p.y < -12:
			bullet.visual.queue_free()
			rounds.remove_at(index)
		else:
			bullet.visual.global_position = bullet.p
