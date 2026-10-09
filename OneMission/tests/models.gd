extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = root.global_transform.affine_inverse() * child.global_transform
		var box: AABB = transform * child.get_aabb()
		result = box if not initialized else result.merge(box)
		initialized = true
	return result
func run() -> void:
	var mission = load("res://Mission.tscn").instantiate()
	root.add_child(mission)
	for actor in mission.enemies + mission.squad + [mission.player]:
		actor.set_physics_process(false)
	check(mission.models.prototypes.size() == 13, "all 13 original GLB model groups are loaded")
	check(not mission.models.visible, "template library stays hidden")
	var panel = mission.models.spawn("WallPanel", mission)
	var panel_bounds := bounds(panel)
	check(absf(panel_bounds.size.x - 1) < 0.03 and absf(panel_bounds.size.y - 1.0667) < 0.03 and panel_bounds.size.z < 0.25, "textured wall panel aligns with destruction collision")
	var textured := false
	for child in panel.find_children("*", "MeshInstance3D", true, false):
		for i in range(child.mesh.get_surface_count()):
			var mat: Material = child.get_active_material(i)
			if mat is StandardMaterial3D and mat.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) != null:
				textured = true
	check(textured, "panel contains embedded wood texture")
	var tree = mission.models.spawn("Pine_A", mission)
	var tree_bounds := bounds(tree)
	check(tree_bounds.size.y > 6 and tree_bounds.size.x > 2, "pine model has real branch canopy rather than single cone")
	var alpha_test := false
	for child in tree.find_children("*", "MeshInstance3D", true, false):
		for i in range(child.mesh.get_surface_count()):
			var mat: Material = child.get_active_material(i)
			if mat is StandardMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				alpha_test = true
	check(alpha_test, "needle cards use alpha cutout instead of alpha-blended forest")
	var rifle = mission.models.spawn("Rifle", mission)
	check(bounds(rifle).position.z < -1, "rifle model muzzle points along negative Z")
	check(mission.squad[0].left_leg != null and mission.squad[0].right_leg != null, "soldier model preserves independent walking pivots")
	check(mission.models.uniform_materials.size() == 2, "friendly and hostile soldiers retain different shared uniform colors")
	var roof = mission.models.spawn("HutRoof", mission)
	check(bounds(roof).size.y > 0.8, "hut roof has a pitched profile")
	check(panel.find_children("*", "MeshInstance3D", true, false).size() == 1 and tree.find_children("*", "MeshInstance3D", true, false).size() == 1, "geometry is merged per model for fewer draw calls")
	var enabled: bool = mission.sunlight.shadow_enabled
	mission.toggle_shadows()
	check(mission.sunlight.shadow_enabled != enabled, "F8 quality toggle can disable shadow cost")
	mission.toggle_shadows()
	mission.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
