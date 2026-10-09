extends CharacterBody3D
var mission: Node3D
var friendly := false
var health := 100.0
var slot := 0
var home := Vector3.ZERO
var last_seen := Vector3.ZERO
var memory := 0.0
var cooldown := 0.0
var patrol_clock := 0.0
var alive := true
var visual: Node3D
var left_leg: Node3D
var right_leg: Node3D

func _ready() -> void:
	mission = get_parent()
	collision_layer = 2
	collision_mask = 3
	home = global_position
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)
	visual = mission.models.spawn("Soldier", self)
	mission.models.apply_uniform(visual, friendly)
	left_leg = visual.find_child("LegLeft", true, false)
	right_leg = visual.find_child("LegRight", true, false)

func visible(target: Node3D) -> bool:
	if global_position.distance_to(target.global_position) > 52:
		return false
	var eye := global_position + Vector3.UP * 1.4
	var point := target.global_position + Vector3.UP * 1.0
	if target == mission.player:
		point = mission.player.camera.global_position
	if not friendly and memory <= 0:
		var toward := (point - eye).normalized()
		if (-global_basis.z).dot(toward) < 0.5:
			return false
	var ray := PhysicsRayQueryParameters3D.create(eye, point)
	ray.exclude = [get_rid()]
	ray.collision_mask = 3
	var contact := get_world_3d().direct_space_state.intersect_ray(ray)
	return not contact.is_empty() and contact.collider == target

func _physics_process(delta: float) -> void:
	if not alive or mission.ended:
		return
	cooldown = maxf(0, cooldown - delta)
	memory = maxf(0, memory - delta)
	patrol_clock += delta
	var destination := home
	var target: Node3D = null
	if friendly:
		if mission.following:
			var offset := Vector3((slot - 1) * 1.1, 0, 2.5 + slot * 0.7)
			destination = mission.player.global_position + mission.player.global_basis * offset
			# All river crossings follow bridge waypoints, never teleport.
			if global_position.z > 9 and destination.z < 9:
				destination = Vector3((slot - 1) * 1.1, 0, 7)
			elif global_position.z > -9 and destination.z < -9:
				destination = Vector3((slot - 1) * 1.1, 0, -12)
			elif global_position.z < -9 and destination.z > -9:
				destination = Vector3((slot - 1) * 1.1, 0, -7)
			elif global_position.z < 9 and destination.z > 9:
				destination = Vector3((slot - 1) * 1.1, 0, 12)
		for enemy in mission.enemies:
			if enemy.alive and visible(enemy):
				target = enemy
				break
	else:
		# Patrol sectors remain on their bank. Alarm grants last-known position,
		# not perpetual knowledge of every soldier's position.
		destination = home + Vector3(sin(patrol_clock * 0.22) * 4, 0, cos(patrol_clock * 0.22) * 3)
		var candidates: Array = [mission.player]
		candidates.append_array(mission.squad)
		for candidate in candidates:
			if candidate.health > 0 and visible(candidate):
				target = candidate
				last_seen = candidate.global_position
				memory = 8
				mission.alarm = true
				break
		if memory > 0:
			destination = last_seen
			destination.z = maxf(11, destination.z) if home.z > 0 else minf(-11, destination.z)
	if target != null:
		var direction := target.global_position + Vector3.UP * 1.0 - (global_position + Vector3.UP * 1.4)
		if cooldown <= 0:
			direction = direction.normalized() + Vector3(randf_range(-0.045, 0.045), randf_range(-0.025, 0.025), randf_range(-0.045, 0.045))
			mission.ballistics.fire(global_position + Vector3.UP * 1.4, direction, self, 42 if friendly else 22, not friendly)
			cooldown = randf_range(1.5, 2.8)
		if not friendly:
			destination = global_position
	var movement := destination - global_position
	movement.y = 0
	var speed := 3.8 if friendly else 1.5
	if movement.length() > (0.6 if friendly else 1.4):
		movement = movement.normalized()
		velocity.x = movement.x * speed
		velocity.z = movement.z * speed
		rotation.y = atan2(-movement.x, -movement.z)
	else:
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor():
		velocity.y -= delta * 9.81
	else:
		velocity.y = 0
	move_and_slide()
	if is_instance_valid(left_leg) and is_instance_valid(right_leg):
		var gait := sin(patrol_clock * 8) * 0.28 if Vector2(velocity.x, velocity.z).length() > 0.1 else 0.0
		left_leg.rotation.x = gait
		right_leg.rotation.x = -gait
	if global_position.y < -4:
		take_damage(100)

func take_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(0, health - amount)
	if health <= 0:
		alive = false
		collision_layer = 0
		collision_mask = 0
		rotation.z = PI / 2
		position.y = 0.18
