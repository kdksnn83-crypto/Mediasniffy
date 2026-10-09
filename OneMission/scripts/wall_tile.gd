extends StaticBody3D
var building: Node3D
var health := 100.0
var destroyed := false
var supports_roof := false
var support_column := -1
var tile_row := 0
var tile_size := Vector3.ONE
var material_name := "wood"
var damage_texture: MeshInstance3D

func apply_projectile_energy(joules: float) -> void:
	apply_blast_damage(maxf(0, joules) / float(building.mission.destruction.settings.projectile_joules_per_health))

func apply_blast_damage(amount: float) -> void:
	if destroyed or amount <= 0:
		return
	health = maxf(0, health - amount)
	if health <= 0:
		destroyed = true
		collision_layer = 0
		hide()
		building.tile_removed(self)
	else:
		# Dark grooves make damaged planks visible without changing shared materials.
		if not is_instance_valid(damage_texture):
			for side in [-1, 1]:
				damage_texture = building.mission.box(self, Vector3(0, 0, side * (tile_size.z / 2 + 0.003)), Vector3(tile_size.x * 0.65, 0.035, 0.012), Color(0.07, 0.06, 0.045)).get_child(0)
