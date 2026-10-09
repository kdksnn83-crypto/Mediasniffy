extends RigidBody3D
var mission: Node3D
var fuse := 3.0
var detonated := false
func _physics_process(delta: float) -> void:
	if detonated:
		return
	if mission.ended:
		queue_free()
		return
	fuse -= delta
	if fuse <= 0:
		detonated = true
		mission.destruction.explode(global_position, float(mission.destruction.settings.grenade_radius_m), float(mission.destruction.settings.grenade_peak_damage))
		queue_free()
