class_name Grid
extends Node2D

signal seed_changed(new_seed: int)

@export var config: GridConfig

var width: int = 0
var height: int = 0
var cell_size: int = 0
var seed_value: int = 0
var rng: RandomNumberGenerator

var start: Vector2i = Vector2i.ZERO
var end: Vector2i = Vector2i(-1, -1)

const _DIM_MODULATE := Color(0.4, 0.4, 0.4, 1.0)
const _BLACK_TEXTURE_NAME := "black"

var _cells: Array = []
var _sprites: Array = []
var _texture_cache: Dictionary = {}
var _black_texture_fallback: Texture2D = null


func _ready() -> void:
	_ensure_config()
	_build(config.seed_input)
	GameManager.report_ready("Grid", "%dx%d, cellSize=%d, seed=%d" % [width, height, cell_size, seed_value])


func _draw() -> void:
	if not config.draw_debug_overlay or _cells.is_empty():
		return

	var outline_color := Color(1, 1, 1, 0.25)
	var wall_color := Color(1, 0.2, 0.2, 0.35)
	var explored_color := Color(1, 1, 0.4, 0.15)

	for x in range(width):
		for y in range(height):
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			var cell: GridCell = _cells[y * width + x]
			if not cell.is_walkable:
				draw_rect(rect, wall_color, true)
			if cell.is_explored:
				draw_rect(rect, explored_color, true)
			draw_rect(rect, outline_color, false)


func get_seed() -> int:
	return seed_value


func load_seed(new_seed: int) -> void:
	_tear_down()
	_build(new_seed)
	seed_changed.emit(seed_value)


func get_cell(coords: Vector2i) -> GridCell:
	if in_bounds(coords):
		return _cells[coords.y * width + coords.x]
	return null


func try_get_cell(coords: Vector2i) -> GridCell:
	if not in_bounds(coords):
		return null
	return _cells[coords.y * width + coords.x]


func in_bounds(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < width and coords.y >= 0 and coords.y < height


func cell_to_world(coords: Vector2i) -> Vector2:
	return Vector2(coords.x * cell_size + cell_size / 2.0, coords.y * cell_size + cell_size / 2.0)


func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / cell_size), floori(world.y / cell_size))


func is_walkable(coords: Vector2i) -> bool:
	if not in_bounds(coords):
		return false
	var cell: GridCell = _cells[coords.y * width + coords.x]
	return cell.is_walkable


func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff := a - b
	return absi(diff.x) + absi(diff.y) == 1


func can_move(from_coords: Vector2i, to_coords: Vector2i) -> bool:
	return in_bounds(from_coords) and in_bounds(to_coords) and are_adjacent(from_coords, to_coords) and is_walkable(to_coords)


func update_visibility_from(origin: Vector2i, bright_radius: float, dim_radius: float, reveal_all: bool) -> void:
	if _cells.is_empty() or _sprites.is_empty():
		return
	var bright2 := bright_radius * bright_radius
	var dim2 := dim_radius * dim_radius
	for x in range(width):
		for y in range(height):
			var cell: GridCell = _cells[y * width + x]
			var state: int
			if reveal_all:
				state = GridCell.Visibility.FULL
			else:
				var dx := float(x - origin.x)
				var dy := float(y - origin.y)
				var dist2 := dx * dx + dy * dy
				if dist2 <= bright2:
					state = GridCell.Visibility.FULL
				elif dist2 <= dim2:
					state = GridCell.Visibility.DIM
				else:
					state = GridCell.Visibility.HIDDEN
			cell.visibility = state
			if state == GridCell.Visibility.FULL:
				cell.is_explored = true
			if state != GridCell.Visibility.HIDDEN:
				cell.has_been_seen = true
			_apply_cell_visibility(_sprites[y * width + x], cell)
	queue_redraw()


func refresh_cell_visual(coords: Vector2i) -> void:
	if not in_bounds(coords):
		return
	var idx := coords.y * width + coords.x
	_apply_cell_visibility(_sprites[idx], _cells[idx])
	queue_redraw()


func refresh_all() -> void:
	if _cells.is_empty() or _sprites.is_empty():
		return
	for x in range(width):
		for y in range(height):
			var idx := y * width + x
			_apply_cell_visibility(_sprites[idx], _cells[idx])
	queue_redraw()


func _ensure_config() -> void:
	if config != null:
		return
	push_warning("Grid: Config not set, using defaults")
	config = GridConfig.new()


func _build(requested_seed: int) -> void:
	_ensure_config()
	width = config.width
	height = config.height
	cell_size = config.cell_size

	seed_value = requested_seed if requested_seed != 0 else _pick_random_seed()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	print("Grid: building cells (seed=%d)" % seed_value)

	_cells.resize(width * height)
	_sprites.resize(width * height)

	for x in range(width):
		for y in range(height):
			var coords := Vector2i(x, y)
			var cell := GridCell.new(coords)
			_cells[y * width + x] = cell

			var sprite := Sprite2D.new()
			sprite.name = "Cell_%d_%d" % [x, y]
			sprite.centered = true
			sprite.position = cell_to_world(coords)
			_apply_cell_visibility(sprite, cell)
			add_child(sprite)
			_sprites[y * width + x] = sprite

	queue_redraw()


func _tear_down() -> void:
	if _sprites.is_empty():
		return
	for sprite in _sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_sprites = []
	_cells = []


func _apply_cell_visibility(sprite: Sprite2D, cell: GridCell) -> void:
	sprite.visible = true
	if not cell.has_been_seen:
		_apply_texture_direct(sprite, _get_black_texture())
		sprite.modulate = Color.WHITE
	else:
		_apply_texture(sprite, cell)
		sprite.modulate = Color.WHITE if cell.visibility == GridCell.Visibility.FULL else _DIM_MODULATE
	if cell.contents != null and is_instance_valid(cell.contents) and cell.contents is Node2D:
		(cell.contents as Node2D).visible = cell.visibility == GridCell.Visibility.FULL


func _get_black_texture() -> Texture2D:
	var loaded := _load_texture_for_kind(_BLACK_TEXTURE_NAME)
	if loaded != null:
		return loaded
	if _black_texture_fallback != null:
		return _black_texture_fallback
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.BLACK)
	_black_texture_fallback = ImageTexture.create_from_image(image)
	return _black_texture_fallback


func _apply_texture_direct(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		sprite.scale = Vector2(
			float(cell_size) / texture.get_width(),
			float(cell_size) / texture.get_height()
		)
	else:
		sprite.scale = Vector2.ONE


func _apply_texture(sprite: Sprite2D, cell: GridCell) -> void:
	var texture := _load_texture_for_kind(cell.kind)
	sprite.texture = texture
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		sprite.scale = Vector2(
			float(cell_size) / texture.get_width(),
			float(cell_size) / texture.get_height()
		)
	else:
		sprite.scale = Vector2.ONE


func _load_texture_for_kind(kind: String) -> Texture2D:
	if kind.is_empty():
		return null
	if _texture_cache.has(kind):
		return _texture_cache[kind]
	var path := config.textures_root.trim_suffix("/") + "/" + kind + ".png"
	if not ResourceLoader.exists(path):
		push_warning("Grid: texture not found at %s" % path)
		_texture_cache[kind] = null
		return null
	var texture: Texture2D = load(path)
	_texture_cache[kind] = texture
	return texture


static func _pick_random_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var value: int = r.seed
	return value if value != 0 else 1
