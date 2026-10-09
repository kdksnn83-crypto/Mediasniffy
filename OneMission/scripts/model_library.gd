extends Node3D
var prototypes: Dictionary = {}
const NAMES := ["WallPanel", "HutRoof", "Window", "Lantern", "Pine_A", "Pine_B", "Rifle", "Splinter", "MetalShard", "Crate", "Soldier", "Locomotive", "Wagon"]
func _ready() -> void:
	var packed: PackedScene = load("res://assets/models/nasser_stahl.glb")
	var library: Node3D = packed.instantiate()
	add_child(library)
	hide()
	for model_name in NAMES:
		var source := library.find_child(model_name, true, false)
		assert(source != null, "Missing model: " + model_name)
		prototypes[model_name] = source
	var seen: Dictionary = {}
	for mesh_node in library.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material: Material = mesh_node.get_active_material(surface)
			if not material is StandardMaterial3D or seen.has(material.get_instance_id()):
				continue
			seen[material.get_instance_id()] = true
			var kind := "wood"
			if "steel" in material.resource_name.to_lower():
				kind = "steel"
			elif "needles" in material.resource_name.to_lower():
				kind = "foliage"
			elif "glass" in material.resource_name.to_lower() or "skin" in material.resource_name.to_lower() or "wool" in material.resource_name.to_lower():
				continue
			get_parent().weather.register_material(material, kind)

func spawn(model_name: String, parent: Node3D, offset: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> Node3D:
	var model: Node3D = prototypes[model_name].duplicate()
	parent.add_child(model)
	model.position = offset
	model.scale *= size
	return model

var uniform_materials: Dictionary = {}
func apply_uniform(model: Node3D, friendly: bool) -> void:
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh_node.mesh.get_surface_count()):
			var base: Material = mesh_node.get_active_material(surface)
			if not base is StandardMaterial3D or "wool" not in base.resource_name.to_lower():
				continue
			var key := str(base.get_instance_id()) + str(friendly)
			if not uniform_materials.has(key):
				var tinted: StandardMaterial3D = base.duplicate()
				tinted.albedo_color = Color(0.95, 1.0, 0.90) if friendly else Color(1.10, 0.90, 1.20)
				uniform_materials[key] = tinted
			mesh_node.set_surface_override_material(surface, uniform_materials[key])
