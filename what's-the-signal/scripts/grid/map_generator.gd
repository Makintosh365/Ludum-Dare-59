class_name MapGenerator
extends Node

signal map_generated(start: Vector2i, end: Vector2i, path_length: int)

@export var config: MapConfig

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _rejected: int = 0


func _ready() -> void:
	_ensure_config()
	GameManager.report_ready("MapGenerator", "pathLength=%d..%d, branch=%s, turn=%s" % [
		config.min_path_length, config.max_path_length, config.branch_chance, config.turn_chance
	])


func generate(grid: Grid) -> void:
	if grid == null or grid.rng == null:
		push_warning("MapGenerator: grid/Rng not ready")
		return
	_ensure_config()

	var rng := grid.rng
	var target_length := _choose_path_length(rng)
	var min_acceptable := maxi(1, config.min_path_length)
	var max_attempts := maxi(1, config.max_generation_attempts)

	print("MapGenerator: starting (seed=%d, targetLength=%d)" % [grid.get_seed(), target_length])

	_rejected = 0
	var path_cells := _try_carve_to_minimum(grid, rng, target_length, max_attempts, min_acceptable)

	if path_cells.size() < min_acceptable:
		path_cells = _try_fallback_seeds(grid, target_length, max_attempts, min_acceptable)
		rng = grid.rng

	var junctions_added := _add_junctions(grid, rng)
	_fill_terrain(grid, rng)
	_compute_distances(grid, path_cells)

	grid.start = path_cells[0]
	grid.end = path_cells[path_cells.size() - 1]
	grid.refresh_all()

	var total_walkable := path_cells.size() + junctions_added
	print("MapGenerator: done — %d path + %d junctions = %d walkable, %s -> %s" % [
		path_cells.size(), junctions_added, total_walkable, grid.start, grid.end
	])
	map_generated.emit(grid.start, grid.end, total_walkable)


func _ensure_config() -> void:
	if config != null:
		return
	push_warning("MapGenerator: Config not set, using defaults")
	config = MapConfig.new()


func _choose_path_length(rng: RandomNumberGenerator) -> int:
	var min_len := maxi(1, config.min_path_length)
	var max_len := maxi(min_len, config.max_path_length)
	return rng.randi_range(min_len, max_len)


func _try_carve_to_minimum(grid: Grid, rng: RandomNumberGenerator, target_length: int, max_attempts: int, min_acceptable: int) -> Array:
	var result: Array = []
	for attempt in range(1, max_attempts + 1):
		_reset_cells(grid)
		result = _carve_path(grid, rng, target_length)
		if result.size() >= min_acceptable:
			return result
		if attempt < max_attempts:
			print("MapGenerator: attempt #%d produced %d cells (< %d), regenerating" % [attempt, result.size(), min_acceptable])
	return result


func _try_fallback_seeds(grid: Grid, target_length: int, max_attempts: int, min_acceptable: int) -> Array:
	var fallbacks := config.fallback_seeds
	if fallbacks == null or fallbacks.size() == 0:
		push_warning("MapGenerator: primary seed exhausted and no fallback seeds configured")
		return _collect_current_path(grid)

	print("MapGenerator: primary seed exhausted, trying %d fallback seed(s)" % fallbacks.size())
	var result: Array = []
	for i in range(fallbacks.size()):
		var fallback: int = fallbacks[i]
		print("MapGenerator: fallback #%d/%d — reloading grid with seed=%d" % [i + 1, fallbacks.size(), fallback])
		grid.load_seed(fallback)
		var new_target := _choose_path_length(grid.rng)
		result = _try_carve_to_minimum(grid, grid.rng, new_target, max_attempts, min_acceptable)
		if result.size() >= min_acceptable:
			print("MapGenerator: accepted fallback #%d (seed=%d, %d cells)" % [i + 1, fallback, result.size()])
			return result

	push_warning("MapGenerator: all fallback seeds exhausted — using best path (%d/%d cells)" % [result.size(), min_acceptable])
	return result if not result.is_empty() else _collect_current_path(grid)


static func _collect_current_path(grid: Grid) -> Array:
	var list: Array = []
	for x in range(grid.width):
		for y in range(grid.height):
			var coords := Vector2i(x, y)
			if grid.get_cell(coords).is_walkable:
				list.append(coords)
	return list


func _reset_cells(grid: Grid) -> void:
	for x in range(grid.width):
		for y in range(grid.height):
			var cell := grid.get_cell(Vector2i(x, y))
			cell.is_walkable = false
			cell.is_explored = false
			cell.distance_from_start = -1
			cell.kind = CellKinds.WALKABLE


func _fill_terrain(grid: Grid, rng: RandomNumberGenerator) -> void:
	for x in range(grid.width):
		for y in range(grid.height):
			var cell := grid.get_cell(Vector2i(x, y))
			if not cell.is_walkable:
				cell.kind = _pick_terrain_kind(rng)


func _carve_path(grid: Grid, rng: RandomNumberGenerator, target_length: int) -> Array:
	var visited: Dictionary = {}
	var path: Array = []

	var current := _resolve_start(grid)
	var direction := _random_direction(rng)
	_mark_walkable(grid, current)
	visited[current] = true
	path.append(current)

	var backtracks := 0
	var branches := 0
	var safety := target_length * 32

	while path.size() < target_length and safety > 0:
		safety -= 1
		if rng.randf() < config.turn_chance:
			direction = _random_direction(rng)

		var step := _try_step(grid, rng, current, direction, visited)
		if not step["ok"]:
			var back := _try_backtrack(grid, path, visited, rng)
			if not back["ok"]:
				break
			current = back["resume_at"]
			direction = back["resume_dir"]
			backtracks += 1
			continue

		current = step["next"]
		direction = step["direction"]
		_mark_walkable(grid, current)
		visited[current] = true
		path.append(current)

		if path.size() > 2 and rng.randf() < config.branch_chance:
			current = path[int(rng.randi() % path.size())]
			direction = _random_direction(rng)
			branches += 1

	if _rejected > 0 or branches > 0:
		print("MapGenerator: %d rejected, %d branches, %d backtracks" % [_rejected, branches, backtracks])
	return path


func _try_step(grid: Grid, rng: RandomNumberGenerator, from_coords: Vector2i, direction: Vector2i, visited: Dictionary) -> Dictionary:
	var next := from_coords + direction
	if _can_place_walkable(grid, next, visited):
		return {"ok": true, "next": next, "direction": direction}
	for alt in _shuffled_directions(rng):
		if alt == direction:
			continue
		var candidate := from_coords + alt
		if _can_place_walkable(grid, candidate, visited):
			return {"ok": true, "next": candidate, "direction": alt}
	return {"ok": false}


func _try_backtrack(grid: Grid, path: Array, visited: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	for i in range(path.size() - 1, -1, -1):
		var candidate: Vector2i = path[i]
		for dir in _shuffled_directions(rng):
			if _can_place_walkable(grid, candidate + dir, visited):
				return {"ok": true, "resume_at": candidate, "resume_dir": dir}
	return {"ok": false}


func _add_junctions(grid: Grid, rng: RandomNumberGenerator) -> int:
	var target := rng.randi_range(maxi(0, config.min_junctions), maxi(config.min_junctions, config.max_junctions))
	if target <= 0:
		return 0

	var candidates: Array = []
	for x in range(grid.width):
		for y in range(grid.height):
			var coords := Vector2i(x, y)
			if _is_junction_candidate(grid, coords):
				candidates.append(coords)

	var created := 0
	while created < target and candidates.size() > 0:
		var idx := rng.randi_range(0, candidates.size() - 1)
		var pick: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		if not _is_junction_candidate(grid, pick):
			continue
		_mark_walkable(grid, pick)
		created += 1

	if created < target:
		push_warning("MapGenerator: only created %d/%d junctions" % [created, target])
	return created


func _is_junction_candidate(grid: Grid, coords: Vector2i) -> bool:
	var cell := grid.get_cell(coords)
	if cell.is_walkable:
		return false

	var walkable_neighbors := _count_walkable_neighbors(grid, coords)
	if walkable_neighbors < 2 or walkable_neighbors > config.max_junction_neighbors:
		return false
	if config.forbid_double_width and _would_create_2x2_block(grid, coords):
		return false
	for dir in DIRECTIONS:
		var n := coords + dir
		if grid.in_bounds(n) and grid.get_cell(n).is_walkable \
				and _count_walkable_neighbors(grid, n) + 1 > config.max_junction_neighbors:
			return false
	return true


func _can_place_walkable(grid: Grid, coords: Vector2i, visited: Dictionary) -> bool:
	if not grid.in_bounds(coords) or visited.has(coords):
		return false
	if _count_walkable_neighbors(grid, coords) > config.max_path_neighbors:
		_rejected += 1
		return false
	if config.forbid_double_width and _would_create_2x2_block(grid, coords):
		_rejected += 1
		return false
	for dir in DIRECTIONS:
		var n := coords + dir
		if grid.in_bounds(n) and grid.get_cell(n).is_walkable \
				and _count_walkable_neighbors(grid, n) + 1 > config.max_path_neighbors:
			_rejected += 1
			return false
	return true


static func _count_walkable_neighbors(grid: Grid, coords: Vector2i) -> int:
	var count := 0
	for dir in DIRECTIONS:
		var n := coords + dir
		if grid.in_bounds(n) and grid.get_cell(n).is_walkable:
			count += 1
	return count


static func _would_create_2x2_block(grid: Grid, coords: Vector2i) -> bool:
	for ox in range(-1, 1):
		for oy in range(-1, 1):
			if _square_2x2_fully_walkable(grid, coords, Vector2i(coords.x + ox, coords.y + oy)):
				return true
	return false


static func _square_2x2_fully_walkable(grid: Grid, promoted: Vector2i, top_left: Vector2i) -> bool:
	for dx in range(2):
		for dy in range(2):
			var c := Vector2i(top_left.x + dx, top_left.y + dy)
			if c == promoted:
				continue
			if not grid.in_bounds(c) or not grid.get_cell(c).is_walkable:
				return false
	return true


static func _compute_distances(grid: Grid, path_cells: Array) -> void:
	if path_cells.is_empty():
		return
	var queue: Array = []
	var start: Vector2i = path_cells[0]
	grid.get_cell(start).distance_from_start = 0
	queue.push_back(start)

	while queue.size() > 0:
		var here: Vector2i = queue.pop_front()
		var here_dist: int = grid.get_cell(here).distance_from_start
		for dir in DIRECTIONS:
			var n := here + dir
			if not grid.in_bounds(n):
				continue
			var cell := grid.get_cell(n)
			if not cell.is_walkable or cell.distance_from_start >= 0:
				continue
			cell.distance_from_start = here_dist + 1
			queue.push_back(n)


static func _mark_walkable(grid: Grid, coords: Vector2i) -> void:
	var cell := grid.get_cell(coords)
	cell.is_walkable = true
	cell.kind = CellKinds.WALKABLE


func _resolve_start(grid: Grid) -> Vector2i:
	if grid.in_bounds(config.start_coords):
		return config.start_coords
	return Vector2i(0, int(grid.height / 2))


func _pick_terrain_kind(rng: RandomNumberGenerator) -> String:
	var kinds := config.terrain_kinds
	if kinds == null or kinds.size() == 0:
		return CellKinds.FOREST

	var total := 0.0
	for i in range(kinds.size()):
		total += _weight_at(i)
	if total <= 0.0:
		return kinds[int(rng.randi() % kinds.size())]

	var roll := rng.randf() * total
	var acc := 0.0
	for i in range(kinds.size()):
		acc += _weight_at(i)
		if roll <= acc:
			return kinds[i]
	return kinds[kinds.size() - 1]


func _weight_at(i: int) -> float:
	var weights := config.terrain_weights
	if weights == null or i >= weights.size():
		return 1.0
	return maxf(0.0, weights[i])


static func _random_direction(rng: RandomNumberGenerator) -> Vector2i:
	return DIRECTIONS[int(rng.randi() % 4)]


static func _shuffled_directions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var copy: Array[Vector2i] = [DIRECTIONS[0], DIRECTIONS[1], DIRECTIONS[2], DIRECTIONS[3]]
	for i in range(3, 0, -1):
		var j := int(rng.randi() % (i + 1))
		var tmp := copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy
