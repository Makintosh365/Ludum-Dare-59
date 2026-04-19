class_name StatBonusSpawner
extends Node

signal bonuses_spawned(bonuses: Array[StatBonusCell])
signal bonus_opened(coords: Vector2i)

@export var config: StatBonusSpawnConfig

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


func _ready() -> void:
	var count := 0
	if config != null:
		count = config.bonus_count
	GameManager.report_ready("StatBonusSpawner", "count=%d" % count)


func spawn(grid: Grid, _player_coords: Vector2i, parent: Node) -> Array[StatBonusCell]:
	var result: Array[StatBonusCell] = []
	if grid == null or grid.rng == null:
		push_warning("StatBonusSpawner: grid/rng not ready")
		return result
	if config == null:
		push_warning("StatBonusSpawner: config missing")
		return result
	if config.bonus_count <= 0:
		return result

	var dist_from_start := _bfs_distance_map(grid, grid.start)
	if dist_from_start.is_empty():
		push_warning("StatBonusSpawner: start unreachable (dist_from_start empty)")
		return result

	var placed_coords: Array[Vector2i] = []

	for i in range(config.bonus_count):
		var dist_from_any := _multi_source_bfs(grid, placed_coords)
		var candidates := _collect_candidates(grid, dist_from_start, dist_from_any, placed_coords.size() > 0)
		if candidates.is_empty():
			push_warning("StatBonusSpawner: ran out of candidates at %d/%d" % [i, config.bonus_count])
			break

		var pick_index := grid.rng.randi_range(0, candidates.size() - 1)
		var coords: Vector2i = candidates[pick_index]

		var cell_node := StatBonusCell.new()
		cell_node.name = "StatBonus_%d" % i
		cell_node.config = config
		parent.add_child(cell_node)
		cell_node.place_on(grid, coords)
		cell_node.opened.connect(_on_bonus_opened)

		result.append(cell_node)
		placed_coords.append(coords)

	print("StatBonusSpawner: placed %d bonus(es) (requested %d)" % [result.size(), config.bonus_count])
	bonuses_spawned.emit(result)
	return result


func _on_bonus_opened(coords: Vector2i) -> void:
	bonus_opened.emit(coords)


func _collect_candidates(
		grid: Grid,
		dist_from_start: Dictionary,
		dist_from_any: Dictionary,
		has_any_placed: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(grid.width):
		for y in range(grid.height):
			var coords := Vector2i(x, y)
			var cell := grid.get_cell(coords)
			if cell == null or not cell.is_walkable:
				continue
			if coords == grid.start:
				continue
			if cell.has_enemy or cell.has_boss or cell.has_chest or cell.has_stat_bonus:
				continue
			if cell.contents != null:
				continue
			if not dist_from_start.has(coords):
				continue

			var d_start: int = dist_from_start[coords]
			if d_start < config.min_distance_from_start:
				continue
			if config.max_distance_from_start >= 0 and d_start > config.max_distance_from_start:
				continue

			if has_any_placed:
				if not dist_from_any.has(coords):
					continue
				var d_any: int = dist_from_any[coords]
				if d_any < config.min_distance_between_bonuses:
					continue

			out.append(coords)
	return out


static func _bfs_distance_map(grid: Grid, origin: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	if not grid.in_bounds(origin):
		return result
	var origin_cell := grid.get_cell(origin)
	if origin_cell == null or not origin_cell.is_walkable:
		return result
	result[origin] = 0
	var queue: Array = [origin]
	while queue.size() > 0:
		var here: Vector2i = queue.pop_front()
		var here_dist: int = result[here]
		for dir in DIRECTIONS:
			var n: Vector2i = here + dir
			if not grid.in_bounds(n) or result.has(n):
				continue
			var cell := grid.get_cell(n)
			if cell == null or not cell.is_walkable:
				continue
			result[n] = here_dist + 1
			queue.push_back(n)
	return result


static func _multi_source_bfs(grid: Grid, sources: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	if sources.is_empty():
		return result
	var queue: Array = []
	for src in sources:
		if not grid.in_bounds(src):
			continue
		result[src] = 0
		queue.push_back(src)
	while queue.size() > 0:
		var here: Vector2i = queue.pop_front()
		var here_dist: int = result[here]
		for dir in DIRECTIONS:
			var n: Vector2i = here + dir
			if not grid.in_bounds(n) or result.has(n):
				continue
			var cell := grid.get_cell(n)
			if cell == null or not cell.is_walkable:
				continue
			result[n] = here_dist + 1
			queue.push_back(n)
	return result
