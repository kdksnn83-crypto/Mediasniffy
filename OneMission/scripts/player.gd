extends CharacterBody3D
var body_collision: CollisionShape3D
var camera: Camera3D
var mission: Node3D
var health := 100.0
var ammo := 5
var reserve := 35
var cooldown := 0.0
var reload_time := 0.0
var stamina := 100.0
var pitch := 0.0
var aiming := false
var weapon: Node3D
var shot_sound: AudioStreamPlayer

func _ready() -> void:
	mission = get_parent()
	collision_layer = 2
	collision_mask = 3
	var shape := CollisionShape3D.new()
	body_collision = shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.far = 230
	add_child(camera)
	camera.current = true
	weapon = Node3D.new()
	camera.add_child(weapon)
	mission.box(weapon, Vector3(0.19, -0.20, -0.48), Vector3(0.09, 0.12, 0.65), Color(0.25, 0.15, 0.08))
	mission.box(weapon, Vector3(0.19, -0.16, -0.88), Vector3(0.035, 0.035, 0.52), Color(0.15, 0.17, 0.18))
	mission.box(weapon, Vector3(0.19, -0.13, -0.72), Vector3(0.035, 0.035, 0.03), Color(0.08, 0.09, 0.1))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	shot_sound = AudioStreamPlayer.new()
	shot_sound.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(shot_sound)
	shot_sound.stream = mission.make_noise(0.16, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and health > 0:
		var sensitivity := 0.0013 if aiming else 0.0025
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.45, 1.45)
		camera.rotation.x = pitch
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	if mission.ended or health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("reload") and ammo < 5 and reserve > 0 and reload_time <= 0:
		reload_time = 2.6
	if event.is_action_pressed("zero_up"):
		mission.ballistics.adjust_zero(100)
	if event.is_action_pressed("zero_down"):
		mission.ballistics.adjust_zero(-100)
	if event.is_action_pressed("grenade"):
		mission.destruction.throw_grenade()
	if event.is_action_pressed("squad"):
		mission.toggle_squad()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			var count := mini(5 - ammo, reserve)
			ammo += count
			reserve -= count
	if mission.ended or health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity.x = 0
		velocity.z = 0
		return
	aiming = Input.is_action_pressed("aim")
	camera.fov = lerpf(camera.fov, 45.0 if aiming else 75.0, minf(delta * 12, 1))
	weapon.position.x = lerpf(weapon.position.x, -0.19 if aiming else 0.0, minf(delta * 12, 1))
	var crouch := Input.is_action_pressed("crouch")
	camera.position.y = lerpf(camera.position.y, 1.0 if crouch else 1.6, minf(delta * 10, 1))
	# Camera and collision height both change; crouching is not only cosmetic.
	var capsule: CapsuleShape3D = body_collision.shape
	var height := 1.1 if crouch else 1.75
	if not crouch and capsule.height < 1.7:
		var clearance := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.8)
		clearance.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(clearance).is_empty():
			height = 1.1
	capsule.height = height
	body_collision.position.y = height / 2
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var sprint := Input.is_action_pressed("sprint") and not crouch and not aiming and stamina > 5 and input.length() > 0
	var speed := 6.0 if sprint else (1.7 if crouch else 3.5)
	stamina = clampf(stamina + delta * (-22.0 if sprint else 14.0), 0, 100)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0
	move_and_slide()
	if Input.is_action_pressed("fire") and cooldown <= 0 and reload_time <= 0 and ammo > 0:
		ammo -= 1
		cooldown = 0.85
		var spread: float = mission.ballistics.dispersion_half_angle() * (1.0 if aiming else 6.0)
		if direction.length() > 0.1:
			spread *= 3
		if crouch:
			spread *= 0.7
		var forward := -camera.global_basis.z
		var radius := sqrt(randf()) * tan(spread)
		var angle := randf() * TAU
		forward += camera.global_basis.x * radius * cos(angle) + camera.global_basis.y * radius * sin(angle)
		mission.ballistics.fire(camera.global_position, forward, self, 95)
		pitch = clampf(pitch + 0.018, -1.45, 1.45)
		camera.rotation.x = pitch
		shot_sound.play()
		mission.alert(global_position)

func take_damage(amount: float) -> void:
	if mission.ended:
		return
	health = maxf(0, health - amount)
	mission.flash_damage()
	if health <= 0:
		mission.finish(false)

func _exit_tree() -> void:
	if is_instance_valid(shot_sound):
		shot_sound.stop()
