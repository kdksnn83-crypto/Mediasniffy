extends RefCounted
# Game calibration, not certified material/armor penetration data.
static var materials: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/impact_materials.json"))
const EPSILON := 0.0001

enum State { PENETRATED, RICOCHETED, STOPPED }

static func solve(velocity: Vector3, normal: Vector3, mass: float, path_length: float, material: Dictionary) -> Dictionary:
	var stopped := {"state": State.STOPPED, "velocity": Vector3.ZERO, "energy_loss_j": 0.0}
	if mass <= 0 or velocity.length_squared() < 0.000001 or normal.length_squared() < 0.000001:
		return stopped
	var direction := velocity.normalized()
	var surface_normal := normal.normalized()
	var cosine := clampf(-direction.dot(surface_normal), 0, 1)
	var angle := rad_to_deg(acos(cosine))
	var energy := 0.5 * mass * velocity.length_squared()
	var ratio := clampf(float(material.get("ricochet_speed_ratio", 0)), 0, 1)
	if ratio > 0 and angle >= float(material.get("ricochet_angle_deg", 90)):
		var reflected := direction.bounce(surface_normal) * velocity.length() * ratio
		return {"state": State.RICOCHETED, "velocity": reflected, "energy_loss_j": energy * (1 - ratio * ratio)}
	# The path is the measured distance inside the collider, already oblique.
	# J/m × m yields J; density alone is not a penetration resistance.
	var loss := maxf(0, path_length) * maxf(0, float(material.get("resistance_j_per_m", 1000000)))
	if material.get("penetrable", false) and path_length > EPSILON and energy > loss:
		var exit_speed := sqrt(2 * (energy - loss) / mass)
		return {"state": State.PENETRATED, "velocity": direction * exit_speed, "energy_loss_j": loss}
	stopped.energy_loss_j = energy
	return stopped

static func box_exit(body: CollisionObject3D, shape_index: int, hit_position: Vector3, direction: Vector3) -> Dictionary:
	# Restrict penetration to supported convex BoxShape3D colliders. Unsupported
	# shapes stop rounds; an assumed thickness must never teleport through them.
	var owner_id := body.shape_find_owner(shape_index)
	var shape_node = body.shape_owner_get_owner(owner_id)
	if not shape_node is CollisionShape3D or not shape_node.shape is BoxShape3D:
		return {}
	var inverse: Transform3D = shape_node.global_transform.affine_inverse()
	var local_hit: Vector3 = inverse * hit_position
	var local_direction: Vector3 = inverse.basis * direction.normalized()
	var half: Vector3 = shape_node.shape.size * 0.5
	var exit_distance := INF
	for axis in range(3):
		if absf(local_direction[axis]) > 0.000001:
			var plane := half[axis] if local_direction[axis] > 0 else -half[axis]
			var travel := (plane - local_hit[axis]) / local_direction[axis]
			if travel > EPSILON:
				exit_distance = minf(exit_distance, travel)
	if not is_finite(exit_distance):
		return {}
	return {"distance": exit_distance, "position": hit_position + direction.normalized() * exit_distance}
