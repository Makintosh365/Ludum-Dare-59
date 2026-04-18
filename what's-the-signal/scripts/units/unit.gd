class_name Unit
extends Node2D

signal moved(from: Vector2i, to: Vector2i)
signal damaged(amount: int, health_after: int)
signal died

@export var max_health: int = 10
@export var damage: int = 1
@export var attack_speed: float = 1.0
@export var defense: int = 0

var health: int = 0
var coords: Vector2i = Vector2i.ZERO
var grid: Grid = null


func is_alive() -> bool:
	return health > 0


func _ready() -> void:
	health = max_health
	queue_redraw()


func place_on(p_grid: Grid, p_coords: Vector2i) -> void:
	if p_grid == null:
		push_warning("Unit %s: PlaceOn called with null grid" % name)
		return
	if not p_grid.in_bounds(p_coords):
		push_warning("Unit %s: PlaceOn coords %s out of bounds" % [name, p_coords])
		return
	var cell := p_grid.get_cell(p_coords)
	if not cell.is_walkable:
		push_warning("Unit %s: PlaceOn cell %s is not walkable" % [name, p_coords])
	if cell.contents != null and cell.contents != self:
		push_warning("Unit %s: PlaceOn cell %s already occupied by %s" % [name, p_coords, cell.contents])

	grid = p_grid
	coords = p_coords
	cell.contents = self
	position = p_grid.cell_to_world(p_coords)
	_on_placed(p_coords)


func _on_placed(p_coords: Vector2i) -> void:
	if grid == null:
		return
	var cell := grid.get_cell(p_coords)
	if cell == null:
		return
	visible = cell.visibility == GridCell.Visibility.FULL


func try_move(target: Vector2i) -> bool:
	if grid == null:
		return false
	if not grid.can_move(coords, target):
		return false
	var destination := grid.get_cell(target)
	if destination.contents != null:
		return false

	var from_coords := coords
	grid.get_cell(from_coords).contents = null
	destination.contents = self
	coords = target
	position = grid.cell_to_world(target)
	moved.emit(from_coords, target)
	return true


func try_step(direction: Vector2i) -> bool:
	return try_move(coords + direction)


func take_damage(amount: int, source: Variant = null) -> void:
	if not is_alive() or amount <= 0:
		return
	var reduced := maxi(0, amount - defense)
	if reduced == 0:
		return
	health = clampi(health - reduced, 0, max_health)
	damaged.emit(reduced, health)
	if health == 0:
		die(source)


func die(_killer: Variant) -> void:
	if grid != null:
		var cell := grid.get_cell(coords)
		if cell != null and cell.contents == self:
			cell.contents = null
	died.emit()
	queue_free()
