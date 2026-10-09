extends Node3D
const RiverShader = preload("res://shaders/river.gdshader")
const PuddleShader = preload("res://shaders/puddle.gdshader")
var mission: Node3D
var wetness := 0.85
var registered: Array[Dictionary] = []
var puddles: Array = []
var roofs: Array[Dictionary] = []
var water: MeshInstance3D

func _ready() -> void:
	mission = get_parent()
	wetness = clampf(float(mission.destruction.settings.wetness), 0, 1)

func register_material(material: StandardMaterial3D, kind: String) -> void:
	if kind not in ["wood", "steel", "earth", "foliage"]:
		return
	registered.append({"material": material, "dry_color": material.albedo_color, "dry_roughness": material.roughness, "kind": kind})
	if kind == "steel":
		material.metallic = 0.55
	apply_wetness(registered[-1])

func apply_wetness(entry: Dictionary) -> void:
	var mat: StandardMaterial3D = entry.material
	mat.albedo_color = entry.dry_color.darkened(wetness * 0.12)
	var minimum := 0.2 if entry.kind == "steel" else 0.38
	mat.roughness = lerpf(entry.dry_roughness, minimum, wetness)

func set_wetness(value: float) -> void:
	wetness = clampf(value, 0, 1)
	for entry in registered:
		apply_wetness(entry)
	for puddle in puddles:
		puddle.material_override.set_shader_parameter("wetness", wetness)

func build_water() -> void:
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 18)
	plane.subdivide_width = 48
	plane.subdivide_depth = 8
	water.mesh = plane
	water.position.y = -1.1
	var material := ShaderMaterial.new()
	material.shader = RiverShader
	water.material_override = material
	mission.add_child(water)

func build_puddles() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 780
	for i in range(int(mission.destruction.settings.puddle_count)):
		var puddle := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(random.randf_range(0.8, 2.4), random.randf_range(0.7, 1.8))
		puddle.mesh = plane
		var point := Vector3.ZERO
		if i < 8:
			point = Vector3(random.randf_range(-5, 5), 0.055, random.randf_range(13, 43))
		else:
			var fraction := random.randf_range(0.1, 0.9)
			point = mission.detonation_point.lerp(mission.escape_point, fraction)
			point += Vector3(random.randf_range(-1.2, 1.2), 0.055, random.randf_range(-1.2, 1.2))
		puddle.position = point
		var material := ShaderMaterial.new()
		material.shader = PuddleShader
		material.set_shader_parameter("wetness", wetness)
		material.set_shader_parameter("phase", random.randf_range(0, TAU))
		puddle.material_override = material
		mission.add_child(puddle)
		puddles.append(puddle)

func register_roof(roof: Node3D, half_size: Vector2) -> void:
	roofs.append({"node": roof, "half_size": half_size})

func sheltered(point: Vector3) -> bool:
	for entry in roofs:
		var roof: Node3D = entry.node
		if not is_instance_valid(roof) or not roof.visible or (roof.get_parent().get("collapsing") == true):
			continue
		var origin := roof.global_position
		if absf(point.x - origin.x) < entry.half_size.x and absf(point.z - origin.z) < entry.half_size.y and point.y < origin.y - 0.15 and point.y > 0:
			return true
	return false

func _process(delta: float) -> void:
	if is_instance_valid(mission.player) and is_instance_valid(mission.rain_audio):
		var volume := -10.0 if sheltered(mission.player.camera.global_position) else 0.0
		mission.rain_audio.volume_db = lerpf(mission.rain_audio.volume_db, volume, minf(1, delta * 3))
