class_name StatBonusCell
extends Node2D

signal opened(coords: Vector2i)

var grid: Grid = null
var coords: Vector2i = Vector2i.ZERO
var is_open: bool = false
var config: StatBonusSpawnConfig = null


func place_on(p_grid: Grid, p_coords: Vector2i) -> void:
	if p_grid == null:
		push_warning("StatBonusCell: place_on called with null grid")
		return
	if not p_grid.in_bounds(p_coords):
		push_warning("StatBonusCell: place_on coords %s out of bounds" % p_coords)
		return
	var cell := p_grid.get_cell(p_coords)
	if cell == null:
		return

	grid = p_grid
	coords = p_coords
	cell.has_stat_bonus = true
	cell.stat_bonus = self
	position = p_grid.cell_to_world(p_coords)
	visible = cell.visibility == GridCell.Visibility.FULL
	queue_redraw()


func open() -> void:
	if is_open:
		return
	is_open = true
	if grid != null:
		var cell := grid.get_cell(coords)
		if cell != null:
			cell.stat_bonus_opened = true
	queue_redraw()
	opened.emit(coords)


func apply_choice(player: Player, kind: int, amount: float) -> void:
	if player == null or player.stats == null:
		return
	var stats: UnitStats = player.stats
	var stat_kind := kind as UnitStats.Kind
	var new_base: float = stats.get_base(stat_kind) + amount
	stats.set_base(stat_kind, new_base)
	if stat_kind == UnitStats.Kind.MAX_HEALTH and amount > 0.0:
		stats.heal(int(amount))


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
	var fill := Color(0.3, 0.7, 0.4, 0.9) if not is_open else Color(0.5, 0.85, 0.55, 0.6)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color.WHITE, false)
