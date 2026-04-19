class_name ChestSpawner
extends Node

signal chests_spawned(chests: Array[Chest])
signal chest_opened(coords: Vector2i, reward: Dictionary)
signal reward_generated(reward: Dictionary)

@export var config: ChestSpawnConfig

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


func _ready() -> void:
	var count := 0
	if config != null:
		count = config.chest_count
	GameManager.report_ready("ChestSpawner", "count=%d" % count)


func spawn(grid: Grid, _player_coords: Vector2i, parent: Node) -> Array[Chest]:
	var result: Array[Chest] = []
	if grid == null or grid.rng == null:
		push_warning("ChestSpawner: grid/rng not ready")
		return result
	if config == null:
		push_warning("ChestSpawner: config missing")
		return result
	if config.chest_count <= 0:
		return result

	var dist_from_start := _bfs_distance_map(grid, grid.start)
	if dist_from_start.is_empty():
		push_warning("ChestSpawner: start unreachable (dist_from_start empty)")
		return result

	var placed_coords: Array[Vector2i] = []

	for i in range(config.chest_count):
		var dist_from_any_chest := _multi_source_bfs(grid, placed_coords)
		var candidates := _collect_candidates(grid, dist_from_start, dist_from_any_chest, placed_coords.size() > 0)
		if candidates.is_empty():
			push_warning("ChestSpawner: ran out of candidates at %d/%d" % [i, config.chest_count])
			break

		var pick_index := grid.rng.randi_range(0, candidates.size() - 1)
		var coords: Vector2i = candidates[pick_index]

		var chest := Chest.new()
		chest.name = "Chest_%d" % i
		chest.config = config
		parent.add_child(chest)
		chest.place_on(grid, coords)
		chest.chest_opened.connect(_on_chest_opened)
		chest.reward_generated.connect(_on_reward_generated)

		result.append(chest)
		placed_coords.append(coords)

	print("ChestSpawner: placed %d chest(s) (requested %d)" % [result.size(), config.chest_count])
	chests_spawned.emit(result)
	return result


func _on_chest_opened(coords: Vector2i, reward: Dictionary) -> void:
	chest_opened.emit(coords, reward)


func _on_reward_generated(reward: Dictionary) -> void:
	reward_generated.emit(reward)


func _collect_candidates(
		grid: Grid,
		dist_from_start: Dictionary,
		dist_from_any_chest: Dictionary,
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
			if cell.has_enemy or cell.has_boss or cell.has_chest:
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
				if not dist_from_any_chest.has(coords):
					continue
				var d_any: int = dist_from_any_chest[coords]
				if d_any < config.min_distance_between_chests:
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
