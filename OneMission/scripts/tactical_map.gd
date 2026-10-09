extends Control
var mission: Node3D

func point(world: Vector3) -> Vector2:
	return Vector2(22 + (world.x + 90) / 180 * 276, 36 + (world.z + 100) / 200 * 278)

func _process(_delta: float) -> void:
	visible = Input.is_action_pressed("map") and not mission.ended
	if visible:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 340), Color(0.025, 0.06, 0.06, 0.95))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18, 23), "FELDKARTE · N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.82, 0.89, 0.81))
	draw_rect(Rect2(22, 36, 276, 278), Color(0.16, 0.22, 0.16))
	draw_rect(Rect2(22, point(Vector3(0, 0, -9)).y, 276, 25), Color(0.2, 0.36, 0.42))
	draw_line(point(Vector3(0, 0, -95)), point(Vector3(0, 0, 95)), Color(0.53, 0.5, 0.38), 2)
	if not mission.bridge_destroyed:
		draw_line(point(Vector3(0, 0, -10)), point(Vector3(0, 0, 10)), Color(0.8, 0.8, 0.7), 5)
	draw_line(point(mission.detonation_point), point(mission.escape_point), Color(0.38, 0.52, 0.32), 3)
	for location in mission.charge_points:
		draw_circle(point(location), 4, Color(1, 0.66, 0.2))
	draw_circle(point(mission.detonation_point), 5, Color(1, 0.55, 0.15))
	draw_circle(point(mission.escape_point), 6, Color(0.4, 0.9, 0.6))
	draw_string(font, point(mission.escape_point) + Vector2(-20, -10), "Forsthütte", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	for soldier in mission.squad:
		if soldier.alive:
			draw_circle(point(soldier.global_position), 3, Color(0.6, 0.82, 1))
	var p := point(mission.player.global_position)
	draw_circle(p, 4, Color.WHITE)
	var direction: Vector3 = -mission.player.global_basis.z
	draw_line(p, p + Vector2(direction.x, direction.z) * 12, Color.WHITE, 2)
	draw_string(font, Vector2(18, 331), "Weiß: Du · Blau: Trupp · Orange: Sabotage", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
