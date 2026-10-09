extends Node3D
const Tile = preload("res://scripts/wall_tile.gd")
var mission: Node3D
var tiles: Array = []
var roof: Node3D
var supports := 0
var lost_supports := 0
var collapsed := false
var collapsing := false
var roof_tween: Tween

func build(origin: Vector3) -> void:
	position = origin
	# 1 m horizontal panels, 3 rows. Only bottom-row panels carry roof support.
	wall(Vector3(0, 0, 2.5), 6, 0)
	wall(Vector3(-3, 0, 0), 5, PI / 2)
	wall(Vector3(3, 0, 0), 5, PI / 2)
	wall(Vector3(-2, 0, -2.5), 2, 0)
	wall(Vector3(2, 0, -2.5), 2, 0)
	roof = mission.box(self, Vector3(0, 3.3, 0), Vector3(6.5, 0.3, 5.5), Color(0.2, 0.23, 0.24), true, "wood")
	mission.weather.register_roof(roof, Vector2(3.25, 2.75))

func wall(center: Vector3, width: int, angle: float) -> void:
	for column in range(width):
		var column_id := supports
		for row in range(3):
			var tile := Tile.new()
			tile.building = self
			tile.health = float(mission.destruction.settings.wall_tile_health)
			tile.supports_roof = row == 0
			tile.support_column = column_id
			tile.tile_row = row
			tile.tile_size = Vector3(1, 3.2 / 3, 0.2)
			tile.set_meta("ballistic_material", "wood")
			var local_offset := Vector3(column - (width - 1) * 0.5, row * (3.2 / 3) + (3.2 / 6), 0).rotated(Vector3.UP, angle)
			tile.position = center + local_offset
			tile.rotation.y = angle
			add_child(tile)
			mission.box(tile, Vector3.ZERO, tile.tile_size, Color(0.32 + row * 0.012, 0.25, 0.19), false, "wood")
			var collision := CollisionShape3D.new()
			var bounds := BoxShape3D.new()
			bounds.size = tile.tile_size
			collision.shape = bounds
			tile.add_child(collision)
			tiles.append(tile)
			if tile.supports_roof:
				supports += 1

func tile_removed(tile: StaticBody3D) -> void:
	mission.destruction.break_tile(tile)
	if tile.supports_roof:
		lost_supports += 1
		# The panels above a lost foundation do not float in the air.
		for upper in tiles:
			if upper.support_column == tile.support_column and not upper.destroyed:
				upper.apply_blast_damage(upper.health)
	if not collapsing and not collapsed and float(lost_supports) / supports >= float(mission.destruction.settings.roof_support_loss_fraction):
		collapse_roof()

func collapse_roof() -> void:
	if collapsing or collapsed:
		return
	collapsing = true
	# No invisible overhead collision remains while the prepared collapse runs.
	roof.collision_layer = 0
	roof_tween = create_tween()
	roof_tween.set_parallel(true)
	roof_tween.tween_property(roof, "position:y", 0.8, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	roof_tween.tween_property(roof, "rotation:z", 0.16, 1.2)
	roof_tween.set_parallel(false)
	roof_tween.tween_callback(finish_collapse)

func finish_collapse() -> void:
	if collapsed:
		return
	collapsing = false
	collapsed = true
	roof.hide()
	for tile in tiles:
		if tile.destroyed or tile.tile_row == 0:
			continue
		var supported := false
		for below in tiles:
			if below.support_column == tile.support_column and below.tile_row == tile.tile_row - 1 and not below.destroyed:
				supported = true
		if not supported:
			tile.apply_blast_damage(tile.health)
	# Prepared resting rubble: cosmetic so it does not trap the player or squad.
	for i in range(7):
		var rubble: Node3D = mission.box(self, Vector3((i - 3) * 0.7, 0.15, 0), Vector3(0.65, 0.18, 4.5), Color(0.17, 0.2, 0.21))
		rubble.rotation.y = (i % 3 - 1) * 0.08
		mission.destruction.spawn_fragment(global_position + Vector3((i - 3) * 0.5, 1, 0), Vector3(0.5, 0.12, 0.8), Vector3((i - 3) * 0.4, 2, 1))
