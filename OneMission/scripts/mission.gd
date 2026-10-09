extends Node3D
const ModelLibraryScript = preload("res://scripts/model_library.gd")
var models: Node3D
var sunlight: DirectionalLight3D
const DestructionScript = preload("res://scripts/destruction.gd")
const WeatherScript = preload("res://scripts/weather.gd")
var destruction: Node3D
var weather: Node3D
const PlayerScript = preload("res://scripts/player.gd")
const SoldierScript = preload("res://scripts/soldier.gd")
const BallisticsScript = preload("res://scripts/ballistics.gd")
var player: CharacterBody3D
var ballistics: Node3D
var squad: Array = []
var enemies: Array = []
var following := true
var alarm := false
var ended := false
var bridge_destroyed := false
var train_destroyed := false
var train_charge := false
var charges := [false, false]
var charge_points := [Vector3(-2, 0.2, 6), Vector3(2, 0.2, -6)]
var charge_visuals: Array = []
var bridge: Node3D
var bridge_bodies: Array = []
var train: Node3D
var train_clock := 0.0
var train_departure := 200.0
var train_state := "Anfahrt"
var interaction := 0.0
var current_action := ""
var label: Label
var hint: Label
var crosshair: Label
var result: Label
var damage_overlay: ColorRect
var damage_alpha := 0.0
var rain: MultiMeshInstance3D
var rain_clock := 0.0
var rain_positions: Array[Vector3] = []
var effects: Array[Dictionary] = []
var elapsed := 0.0
var terrain_materials: Dictionary = {}
var detonation_point := Vector3(8, 0, -18)
var escape_point := Vector3(-28, 0, -67)
var rain_audio: AudioStreamPlayer

func box(parent: Node, pos: Vector3, size: Vector3, color: Color, solid: bool = false, ballistic_material: String = "unknown") -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var key := str(color) + "|" + ballistic_material
	if not terrain_materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.72
		if is_instance_valid(weather):
			weather.register_material(mat, ballistic_material)
		terrain_materials[key] = mat
	mesh.material_override = terrain_materials[key]
	if ballistic_material == "earth" and is_instance_valid(weather):
		mesh.material_override = weather.terrain_material()
	root.add_child(mesh)
	if solid:
		root.set_meta("ballistic_material", ballistic_material)
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		root.add_child(collision)
	return root

func bind_action(action: String, keys: Array, mouse: int = 0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if mouse > 0:
		var event := InputEventMouseButton.new()
		event.button_index = mouse
		InputMap.action_add_event(action, event)

func _ready() -> void:
	seed(87341)
	bind_action("forward", [KEY_W])
	bind_action("back", [KEY_S])
	bind_action("left", [KEY_A])
	bind_action("right", [KEY_D])
	bind_action("sprint", [KEY_SHIFT])
	bind_action("crouch", [KEY_CTRL])
	bind_action("interact", [KEY_E])
	bind_action("reload", [KEY_R])
	bind_action("grenade", [KEY_G])
	bind_action("squad", [KEY_F])
	bind_action("pause", [KEY_ESCAPE])
	bind_action("restart", [KEY_F5])
	bind_action("map", [KEY_TAB])
	bind_action("shadows", [KEY_F8])
	bind_action("zero_up", [KEY_PAGEUP])
	bind_action("zero_down", [KEY_PAGEDOWN])
	bind_action("fire", [], MOUSE_BUTTON_LEFT)
	bind_action("aim", [], MOUSE_BUTTON_RIGHT)
	destruction = DestructionScript.new()
	add_child(destruction)
	weather = WeatherScript.new()
	add_child(weather)
	models = ModelLibraryScript.new()
	add_child(models)
	build_world()
	ballistics = BallisticsScript.new()
	add_child(ballistics)
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(-5, 0.1, 38)
	for i in range(3):
		var soldier := SoldierScript.new()
		soldier.friendly = true
		soldier.slot = i
		soldier.position = Vector3(-6 + i * 1.2, 0.1, 42)
		add_child(soldier)
		squad.append(soldier)
	for point in [Vector3(12, 0.1, 15), Vector3(13, 0.1, 21), Vector3(-8, 0.1, -24), Vector3(10, 0.1, -34)]:
		spawn_enemy(point)
	build_ui()
	rain_audio = AudioStreamPlayer.new()
	rain_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	rain_audio.stream = make_noise(3, 0.05, true)
	add_child(rain_audio)
	rain_audio.play()

func spawn_enemy(point: Vector3) -> void:
	var enemy := SoldierScript.new()
	enemy.position = point
	add_child(enemy)
	enemies.append(enemy)

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color(0.15, 0.22, 0.27)
	atmosphere.sky_horizon_color = Color(0.34, 0.4, 0.43)
	atmosphere.ground_bottom_color = Color(0.12, 0.15, 0.14)
	atmosphere.ground_horizon_color = Color(0.3, 0.34, 0.34)
	sky.sky_material = atmosphere
	env.sky = sky
	env.background_color = Color(0.22, 0.28, 0.31)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.53, 0.62, 0.67)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.33, 0.41, 0.44)
	env.fog_density = 0.012
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color(0.65, 0.73, 0.8)
	sun.light_energy = 0.75
	sunlight = sun
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	box(self, Vector3(0, -0.5, 55), Vector3(180, 1, 92), Color(0.19, 0.23, 0.16), true, "earth")
	box(self, Vector3(0, -0.5, -55), Vector3(180, 1, 92), Color(0.19, 0.23, 0.16), true, "earth")
	weather.build_water()
	# River bed catches falls; deep water is a lethal hazard.
	box(self, Vector3(0, -4.5, 0), Vector3(180, 1, 18), Color(0.13, 0.17, 0.12), true, "earth")
	for bank in [-1, 1]:
		box(self, Vector3(0, 0.015, bank * 34), Vector3(7, 0.03, 50), Color(0.29, 0.26, 0.2))
	bridge = Node3D.new()
	add_child(bridge)
	bridge_bodies.append(box(bridge, Vector3(0, -0.25, 0), Vector3(6, 0.5, 20), Color(0.25, 0.27, 0.26), true, "steel"))
	for x in [-2.8, 2.8]:
		for z in range(-9, 10, 3):
			box(bridge, Vector3(x, 2, z), Vector3(0.18, 4, 0.18), Color(0.19, 0.24, 0.25))
			var beam := box(bridge, Vector3(x, 2, z + 1.2), Vector3(0.13, 4.6, 0.13), Color(0.19, 0.24, 0.25))
			beam.rotation.x = 0.55 if z % 2 == 0 else -0.55
		box(bridge, Vector3(x, 4, 0), Vector3(0.22, 0.2, 20), Color(0.19, 0.24, 0.25))
		bridge_bodies.append(box(bridge, Vector3(x, 0.8, 0), Vector3(0.15, 0.3, 20), Color(0.2, 0.24, 0.25), true, "steel"))
	for x in [-0.75, 0.75]:
		box(bridge, Vector3(x, 0.3, 0), Vector3(0.08, 0.08, 20), Color(0.45, 0.49, 0.5))
		for bank in [-1, 1]:
			box(self, Vector3(x, 0.08, bank * 44), Vector3(0.08, 0.08, 68), Color(0.42, 0.46, 0.47))
	for z in range(-9, 10):
		box(bridge, Vector3(0, 0.27, z), Vector3(2.2, 0.07, 0.16), Color(0.27, 0.2, 0.14))
	for point in charge_points:
		charge_visuals.append(marker(point + Vector3.UP * 0.6, "SPRENGLADUNG", Color(1, 0.65, 0.15)))
	marker(detonation_point + Vector3.UP, "ZÜNDPUNKT", Color(1, 0.65, 0.15))
	marker(escape_point + Vector3.UP * 2, "PARTISANEN", Color(0.4, 0.85, 0.6))
	build_hut(Vector3(14, 0, 18), false)
	build_hut(escape_point, true)
	var path_vector := escape_point - detonation_point
	var path_mesh := box(self, (escape_point + detonation_point) / 2 + Vector3.UP * 0.025, Vector3(4, 0.04, path_vector.length()), Color(0.29, 0.26, 0.2))
	path_mesh.rotation.y = atan2(path_vector.x, path_vector.z)
	for i in range(30):
		var point := Vector3(randf_range(-18, 18), 0.5, randf_range(-43, -13))
		if route_distance(point) < 3:
			continue
		if absf(point.x) < 3:
			point.x += 5
		var crate := box(self, point, Vector3(1.2, 1, 1.2), Color(0.37, 0.29, 0.19), true, "wood")
		crate.get_child(0).hide()
		models.spawn("Crate", crate)
	# Lightweight forest silhouettes; corridor remains open and readable.
	for i in range(180):
		var x := randf_range(-65, 65)
		var z := randf_range(-85, 85)
		if route_distance(Vector3(x, 0, z)) < 4 or absf(z) < 12 or absf(x) < 8 or Vector2(x + 28, z + 67).length() < 8 or Vector2(x - 14, z - 18).length() < 9:
			continue
		var trunk := box(self, Vector3(x, 2.1, z), Vector3(0.45, 4.2, 0.45), Color(0.2, 0.17, 0.12), true, "wood")
		trunk.get_child(0).hide()
		var tree: Node3D = models.spawn("Pine_A" if i % 2 == 0 else "Pine_B", self, Vector3(x, 0, z))
		tree.rotation.y = float(i) * 1.37
	train = Node3D.new()
	add_child(train)
	train.position = Vector3(0, 0, 74)
	for i in range(4):
		var wagon := box(train, Vector3(0, 1.4, i * 5.5), Vector3(2.1, 2.1, 4.7), Color(0.23, 0.26, 0.22) if i > 0 else Color(0.12, 0.15, 0.16), true, "steel")
		wagon.get_child(0).hide()
		models.spawn("Locomotive" if i == 0 else "Wagon", wagon, Vector3(0, -1.4, 0))
	marker(Vector3(-3.5, 1.3, -25), "ZUGLADUNG (OPTIONAL)", Color(0.85, 0.65, 0.2))
	weather.build_puddles()
	build_rain()

func build_hut(pos: Vector3, partisan: bool) -> void:
	var color := Color(0.32, 0.25, 0.19)
	var front := 1.0 if partisan else -1.0
	if not partisan:
		destruction.build_hut(pos)
	else:
		build_safe_hut(pos, color, front)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 2.2, -1)
	models.spawn("Lantern", self, pos + Vector3(0.6, 2.1, -2.7 if not partisan else 2.7))
	light.light_color = Color(1, 0.63, 0.29)
	light.light_energy = 1.7
	light.omni_range = 10
	add_child(light)
	if partisan:
		box(self, pos + Vector3(1, 0.8, -3.8), Vector3(0.5, 1.6, 0.4), Color(0.31, 0.24, 0.16))

func panel_wall_visual(body: Node3D, width: int, angle: float) -> void:
	body.get_child(0).hide()
	for column in range(width):
		for row in range(3):
			var offset := Vector3(column - (width - 1) * 0.5, row * (3.2 / 3) + 3.2 / 6 - 1.6, 0).rotated(Vector3.UP, angle)
			var panel: Node3D = models.spawn("WallPanel", body, offset)
			panel.rotation.y = angle

func build_safe_hut(pos: Vector3, color: Color, front: float) -> void:
	var back := box(self, pos + Vector3(0, 1.6, -2.5 * front), Vector3(6, 3.2, 0.2), color, true, "wood")
	panel_wall_visual(back, 6, 0)
	for x in [-3, 3]:
		var side := box(self, pos + Vector3(x, 1.6, 0), Vector3(0.2, 3.2, 5), color, true, "wood")
		panel_wall_visual(side, 5, PI / 2)
	for x in [-2, 2]:
		var face := box(self, pos + Vector3(x, 1.6, 2.5 * front), Vector3(2, 3.2, 0.2), color, true, "wood")
		panel_wall_visual(face, 2, 0)
	var roof := box(self, pos + Vector3(0, 3.3, 0), Vector3(6.5, 0.3, 5.5), Color(0.2, 0.23, 0.24), true, "wood")
	roof.get_child(0).hide()
	models.spawn("HutRoof", roof)
	weather.register_roof(roof, Vector2(3.25, 2.75))

func marker(pos: Vector3, text: String, color: Color) -> Node3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = 28
	node.pixel_size = 0.007
	node.modulate = color
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	node.position = pos
	add_child(node)
	return node

func build_rain() -> void:
	rain = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var drop := BoxMesh.new()
	drop.size = Vector3(0.014, 0.38, 0.014)
	multi.mesh = drop
	multi.instance_count = 420
	rain.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.65, 0.72, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain.material_override = mat
	add_child(rain)
	for i in range(420):
		rain_positions.append(Vector3(randf_range(-18, 18), randf_range(0, 17), randf_range(-18, 18)))

func make_noise(duration: float, amplitude: float, looped: bool = false) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var data := PackedByteArray()
	var count := int(duration * 22050)
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 645
	for i in range(count):
		var envelope := 1.0 if looped else exp(-float(i) / count * 8)
		data.encode_s16(i * 2, int(random.randf_range(-1, 1) * amplitude * envelope * 32767))
	audio.data = data
	if looped:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = count
	return audio

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(700, 280)
	panel.color = Color(0.035, 0.055, 0.06, 0.83)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	label = Label.new()
	label.position = Vector2(32, 27)
	label.add_theme_font_size_override("font_size", 17)
	canvas.add_child(label)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(28, 615)
	hint.add_theme_font_size_override("font_size", 18)
	canvas.add_child(hint)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(633, 345)
	crosshair.add_theme_font_size_override("font_size", 24)
	canvas.add_child(crosshair)
	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.color = Color(0.7, 0.05, 0.03, 0)
	canvas.add_child(damage_overlay)
	result = Label.new()
	result.position = Vector2(330, 270)
	result.add_theme_font_size_override("font_size", 27)
	result.visible = false
	canvas.add_child(result)
	var map := preload("res://scripts/tactical_map.gd").new()
	map.mission = self
	map.position = Vector2(938, 355)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(map)

func toggle_squad() -> void:
	following = not following

func alert(point: Vector3) -> void:
	alarm = true
	for enemy in enemies:
		if enemy.alive and enemy.global_position.distance_to(point) < 65:
			enemy.last_seen = point
			enemy.memory = 6

func survivors() -> int:
	var total := 1 if player.health > 0 else 0
	for soldier in squad:
		if soldier.alive:
			total += 1
	return total

func all_across() -> bool:
	if player.global_position.z > -11:
		return false
	for soldier in squad:
		if soldier.alive and soldier.global_position.z > -11:
			return false
	return true

func nearby_action() -> String:
	if not bridge_destroyed:
		for i in range(2):
			if not charges[i] and player.global_position.distance_to(charge_points[i]) < 2.8:
				return "charge" + str(i)
		if not train_charge and train_state == "Entladung" and player.global_position.distance_to(Vector3(-3.5, 0, -25)) < 3.3:
			return "train"
		if player.global_position.distance_to(detonation_point) < 3:
			return "detonate"
	elif player.global_position.distance_to(escape_point) < 6:
		return "escape"
	return ""

func action_prompt(action: String) -> String:
	if action.begins_with("charge"):
		return "E halten: Sprengladung anbringen (3 Sekunden)"
	if action == "train":
		return "E halten: Zug sabotieren (3 Sekunden)"
	if action == "detonate":
		if not charges[0] or not charges[1]:
			return "Zündung gesperrt: Beide Brückenladungen fehlen."
		if not all_across():
			return "Zündung gesperrt: Alle Überlebenden müssen ans Nordufer!"
		return "E halten: Brücke sprengen (2 Sekunden)"
	if action == "escape":
		for soldier in squad:
			if soldier.alive and soldier.global_position.distance_to(escape_point) > 10:
				return "Warte auf den Trupp. F: Folgen."
		return "E halten: Kennwort ‚Nasser Stahl‘ — Mission abschließen"
	return ""

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	damage_alpha = maxf(0, damage_alpha - delta)
	damage_overlay.color.a = damage_alpha
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if effects[i].life <= 0:
			effects[i].node.queue_free()
			effects.remove_at(i)
	for i in range(rain_positions.size()):
		rain_positions[i].y -= delta * 15
		rain_positions[i].x -= delta * 0.7
		if rain_positions[i].y < 0:
			rain_positions[i].y += 17
		var transform := Transform3D.IDENTITY
		transform.origin = player.global_position + rain_positions[i]
		if weather.sheltered(transform.origin):
			transform.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		rain.multimesh.set_instance_transform(i, transform)
	if ended:
		return
	elapsed += delta
	update_train(delta)
	if player.global_position.y < -3 or absf(player.global_position.x) > 87 or absf(player.global_position.z) > 97:
		player.take_damage(100)
	var action := nearby_action()
	var prompt := action_prompt(action)
	var can_act := not action.is_empty() and not prompt.begins_with("Zündung gesperrt") and not prompt.begins_with("Warte")
	if action != current_action or not Input.is_action_pressed("interact") or not can_act or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		interaction = 0
	current_action = action
	if can_act and Input.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		interaction += delta
		var required := 2.0 if action in ["detonate", "escape"] else 3.0
		if interaction >= required:
			perform_action(action)
			interaction = 0
	var objective := "1. Beide Brückenladungen anbringen."
	if charges[0] and charges[1]:
		objective = "2. Trupp ans Nordufer führen; Zündpunkt erreichen."
	if bridge_destroyed:
		objective = "3. Nach Nordwesten zur Forsthütte fliehen."
	label.text = "ONE MISSION · NASSER STAHL\n%s\nBrücke: %s / 2 Ladungen · Zug: %s\nTrupp: %d / 4 · Befehl: %s · %s\nGesundheit: %d · Ausdauer: %d\nPatronen: %d / %d %s\nZug fährt ab in: %d s · Visier: %d m · Granaten: %d (G)\nWASD · Shift Sprint · Strg Ducken · RMB Zielen\nLMB Feuer · R Nachladen · F Folgen/Halten · Tab Karte · Esc Maus · F5 Neustart" % [objective, int(charges[0]) + int(charges[1]), "zerstört" if train_destroyed else train_state, survivors(), "Folgen" if following else "Halten", "ALARM" if alarm else "Unentdeckt", player.health, player.stamina, player.ammo, player.reserve, "(Nachladen)" if player.reload_time > 0 else "", maxi(0, int(train_departure - train_clock)), ballistics.zero_range, destruction.grenades_left]
	hint.text = prompt + ("\nFortschritt: %d %%" % int(interaction / (2.0 if action in ["detonate", "escape"] else 3.0) * 100) if interaction > 0 else "")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		hint.text = "Maus freigegeben — Esc zum Weiterspielen. Welt läuft weiter."
	crosshair.visible = true
	crosshair.text = "·" if player.aiming else "+"

func update_train(delta: float) -> void:
	if train_destroyed:
		return
	train_clock += delta
	if alarm:
		train_departure = minf(train_departure, maxf(65, train_clock + 40))
	if train_clock < 28:
		train_state = "Anfahrt"
		train.position.z = lerpf(74, -30, train_clock / 28)
	elif train_clock < train_departure:
		train_state = "Entladung"
		train.position.z = -30
	else:
		train_state = "Abfahrt"
		train.position.z -= delta * 6
		if train.position.z < -115:
			train_state = "verpasst"
			train.hide()

func perform_action(action: String) -> void:
	if action.begins_with("charge"):
		var index := int(action.right(1))
		charges[index] = true
		charge_visuals[index].modulate = Color(0.4, 0.9, 0.5)
		box(bridge, charge_points[index] + Vector3.UP * 0.25, Vector3(0.4, 0.25, 0.4), Color(0.44, 0.35, 0.18))
	elif action == "train":
		train_charge = true
	elif action == "detonate" and charges[0] and charges[1] and all_across():
		detonate()
	elif action == "escape":
		finish(true)

func detonate() -> void:
	bridge_destroyed = true
	bridge.hide()
	for body in bridge_bodies:
		body.collision_layer = 0
	train_destroyed = train_charge and train_state == "Entladung"
	if train_destroyed:
		train.hide()
		for child in train.get_children():
			if child is StaticBody3D:
				child.collision_layer = 0
	for i in range(18):
		var wreck := box(self, Vector3(randf_range(-3, 3), randf_range(-0.8, 0.3), randf_range(-9, 9)), Vector3(0.25, 0.25, randf_range(2, 5)), Color(0.14, 0.16, 0.17))
		wreck.rotation = Vector3(randf(), randf() * 3, randf())
		destruction.spawn_fragment(Vector3(randf_range(-3, 3), 2, randf_range(-9, 9)), Vector3(0.15, 0.15, 0.6), Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)), "steel")
	var boom := AudioStreamPlayer.new()
	boom.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	boom.stream = make_noise(1.5, 0.45)
	add_child(boom)
	boom.play()
	effects.append({"node": boom, "life": 3.0})
	for z in [-6, 0, 6]:
		destruction.explode(Vector3(0, 1, z), 10.0, 220.0, false)
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 3, z)
		glow.light_color = Color(1, 0.4, 0.08)
		glow.light_energy = 7
		glow.omni_range = 22
		add_child(glow)
		effects.append({"node": glow, "life": 0.5})
		var cloud := box(self, Vector3(0, 2, z), Vector3(3, 3, 3), Color(0.21, 0.22, 0.23))
		effects.append({"node": cloud, "life": 8.0})
	alarm = true
	# Limited reinforcements enter through the existing north road.
	spawn_enemy(Vector3(5, 0.1, -78))
	spawn_enemy(Vector3(8, 0.1, -80))

func impact(point: Vector3) -> void:
	var spark := box(self, point, Vector3(0.08, 0.08, 0.08), Color(1, 0.7, 0.3))
	effects.append({"node": spark, "life": 0.2})

func flash_damage() -> void:
	damage_alpha = 0.35
	interaction = 0

func finish(success: bool) -> void:
	ended = true
	result.visible = true
	result.text = "%s\n\nBrücke zerstört: %s\nZug zerstört: %s\nÜberlebende: %d · Gefallene: %d\nZeit: %d Sekunden\n\nF5: Neu starten · Esc: Maus freigeben" % ["MISSION ABGESCHLOSSEN" if success else "MISSION GESCHEITERT", "Ja" if bridge_destroyed else "Nein", "Ja" if train_destroyed else "Nein / optionales Ziel verpasst", survivors(), 4 - survivors(), elapsed]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func route_distance(point: Vector3) -> float:
	var start := Vector2(detonation_point.x, detonation_point.z)
	var end := Vector2(escape_point.x, escape_point.z)
	var p := Vector2(point.x, point.z)
	var fraction := clampf((p - start).dot(end - start) / (end - start).length_squared(), 0, 1)
	return p.distance_to(start.lerp(end, fraction))

func _exit_tree() -> void:
	for child in find_children("*", "AudioStreamPlayer", true, false):
		child.stop()
		child.stream = null

func toggle_shadows() -> void:
	sunlight.shadow_enabled = not sunlight.shadow_enabled
