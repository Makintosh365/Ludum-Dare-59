class_name Chest
extends Node2D

signal chest_opened(coords: Vector2i, reward: Dictionary)

var grid: Grid = null
var coords: Vector2i = Vector2i.ZERO
var is_open: bool = false
var config: ChestSpawnConfig = null


func place_on(p_grid: Grid, p_coords: Vector2i) -> void:
	if p_grid == null:
		push_warning("Chest: place_on called with null grid")
		return
	if not p_grid.in_bounds(p_coords):
		push_warning("Chest: place_on coords %s out of bounds" % p_coords)
		return
	var cell := p_grid.get_cell(p_coords)
	if cell == null:
		return

	grid = p_grid
	coords = p_coords
	cell.has_chest = true
	cell.chest = self
	position = p_grid.cell_to_world(p_coords)
	visible = cell.visibility == GridCell.Visibility.FULL
	queue_redraw()


func open(player: Player) -> Dictionary:
	if is_open:
		return {}
	var rng: RandomNumberGenerator = grid.rng if grid != null else null
	var reward := RewardGenerator.generate(player, rng)
	RewardGenerator.apply_coins(player, reward)

	is_open = true
	if grid != null:
		var cell := grid.get_cell(coords)
		if cell != null:
			cell.chest_opened = true
	queue_redraw()
	chest_opened.emit(coords, reward)
	return reward


func _draw() -> void:
	var texture: Texture2D = null
	if config != null:
		texture = config.opened_icon if is_open else config.closed_icon

	if texture != null:
		var size: float = float(grid.cell_size) if grid != null and grid.cell_size > 0 else maxf(texture.get_width(), texture.get_height())
		draw_texture_rect(texture, Rect2(-size * 0.5, -size * 0.5, size, size), false)
		return

	var half: float = float(grid.cell_size) * 0.4 if grid != null and grid.cell_size > 0 else 12.0
	var rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	var fill := Color(0.55, 0.4, 0.15, 0.9) if not is_open else Color(0.8, 0.7, 0.3, 0.6)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color.WHITE, false)
